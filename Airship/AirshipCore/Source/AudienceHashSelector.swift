/* Copyright Airship and Contributors */

import Foundation

/// - Note: For internal use only. :nodoc:
public struct AudienceHashSelector: Codable, Sendable, Equatable {
    let hash: Hash
    let bucket: Bucket
    var sticky: Sticky?

    /// Optional time-based overrides for the effective `bucket`. When present, the first
    /// override whose schedule is active for the evaluation date is used to compute the
    /// effective audience subset. Used by automated rollouts to ramp the rollout percentage
    /// entirely on-device from a schedule baked into the payload.
    let overrides: [AudienceSubsetOverride]?

    init(
        hash: Hash,
        bucket: Bucket,
        sticky: Sticky? = nil,
        overrides: [AudienceSubsetOverride]? = nil
    ) {
        self.hash = hash
        self.bucket = bucket
        self.sticky = sticky
        self.overrides = overrides
    }
    
    enum CodingKeys: String, CodingKey {
        case hash = "audience_hash"
        case bucket = "audience_subset"
        case sticky
        case overrides = "audience_subset_overrides"
    }

    struct Hash: Codable, Sendable, Equatable {
        enum Identifier: String, Codable, Equatable {
            case channel, contact
        }

        enum Algorithm: String, Codable, Equatable {
            case farm = "farm_hash"
        }

        let prefix: String
        let property: Identifier
        let algorithm: Algorithm
        let seed: UInt?
        let numberOfBuckets: UInt64
        let overrides: [String: String]?

        enum CodingKeys: String, CodingKey {
            case prefix = "hash_prefix"
            case property = "hash_identifier"
            case algorithm = "hash_algorithm"
            case seed = "hash_seed"
            case numberOfBuckets = "num_hash_buckets"
            case overrides = "hash_identifier_overrides"
        }
    }

    struct Bucket: Codable, Sendable, Equatable {
        let min: UInt64
        let max: UInt64

        enum CodingKeys: String, CodingKey {
            case min = "min_hash_bucket"
            case max = "max_hash_bucket"
        }

        init(min: UInt64, max: UInt64) {
            self.min = min
            self.max = max
        }
    

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.min = try container.decodeIfPresent(UInt64.self, forKey: .min) ?? 0
            self.max = try container.decodeIfPresent(UInt64.self, forKey: .max) ?? UInt64.max
        }

        func contains(_ value: UInt64) -> Bool {
            return value >= min && value <= max
        }
    }

    /// A time-based override for the effective audience subset. Used by automated rollouts
    /// so the rollout percentage can ramp automatically over time, computed on-device from
    /// a schedule baked into the payload.
    enum AudienceSubsetOverride: Codable, Sendable, Equatable {
        /// A static hold at a fixed subset while the schedule is active.
        case `static`(schedule: AirshipTimeCriteria, subset: Bucket)

        /// A linear ramp that interpolates the subset from `subsetStart` to `subsetEnd`
        /// across the schedule window. Both `start_timestamp` and `end_timestamp` are required.
        case linearRamp(schedule: AirshipTimeCriteria, subsetStart: Bucket, subsetEnd: Bucket)

        private enum OverrideType: String, Codable {
            case `static`
            case linearRamp = "linear_ramp"
        }

        enum CodingKeys: String, CodingKey {
            case type
            case subset = "audience_subset"
            case subsetStart = "audience_subset_start"
            case subsetEnd = "audience_subset_end"
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(OverrideType.self, forKey: .type)

            // The schedule window shares the container with the override fields.
            let schedule = try AirshipTimeCriteria(from: decoder)

            switch type {
            case .static:
                let subset = try container.decode(Bucket.self, forKey: .subset)
                self = .static(schedule: schedule, subset: subset)
            case .linearRamp:
                guard schedule.startDate != nil, schedule.endDate != nil else {
                    throw DecodingError.dataCorrupted(
                        DecodingError.Context(
                            codingPath: decoder.codingPath,
                            debugDescription: "linear_ramp override requires both start_timestamp and end_timestamp"
                        )
                    )
                }
                let subsetStart = try container.decode(Bucket.self, forKey: .subsetStart)
                let subsetEnd = try container.decode(Bucket.self, forKey: .subsetEnd)
                self = .linearRamp(
                    schedule: schedule,
                    subsetStart: subsetStart,
                    subsetEnd: subsetEnd
                )
            }
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .static(let schedule, let subset):
                try container.encode(OverrideType.static, forKey: .type)
                try schedule.encode(to: encoder)
                try container.encode(subset, forKey: .subset)
            case .linearRamp(let schedule, let subsetStart, let subsetEnd):
                try container.encode(OverrideType.linearRamp, forKey: .type)
                try schedule.encode(to: encoder)
                try container.encode(subsetStart, forKey: .subsetStart)
                try container.encode(subsetEnd, forKey: .subsetEnd)
            }
        }

        /// The schedule window for this override.
        var schedule: AirshipTimeCriteria {
            switch self {
            case .static(let schedule, _): schedule
            case .linearRamp(let schedule, _, _): schedule
            }
        }

        /// Resolves the effective bucket for this override at the given date.
        func resolveBucket(date: Date) -> Bucket {
            switch self {
            case .static(_, let subset):
                return subset
            case .linearRamp(let schedule, let subsetStart, let subsetEnd):
                return Self.interpolate(
                    schedule: schedule,
                    subsetStart: subsetStart,
                    subsetEnd: subsetEnd,
                    date: date
                )
            }
        }

        private static func interpolate(
            schedule: AirshipTimeCriteria,
            subsetStart: Bucket,
            subsetEnd: Bucket,
            date: Date
        ) -> Bucket {
            // Both timestamps are guaranteed present for linearRamp (validated at decode).
            guard
                let startDate = schedule.startDate,
                let endDate = schedule.endDate,
                endDate > startDate
            else {
                return subsetEnd
            }

            let duration = endDate.timeIntervalSince(startDate)
            let elapsed = date.timeIntervalSince(startDate)
            let t = max(0.0, min(1.0, elapsed / duration))

            // Cast to Double before the subtraction so an inverted (start > end) subset can
            // never underflow in unsigned integer arithmetic.
            let interpolatedMin = UInt64(Double(subsetStart.min) + t * (Double(subsetEnd.min) - Double(subsetStart.min)))
            let interpolatedMax = UInt64(Double(subsetStart.max) + t * (Double(subsetEnd.max) - Double(subsetStart.max)))

            return Bucket(min: interpolatedMin, max: interpolatedMax)
        }
    }

    /// Sticky has will cache the result under the `id` for the length of the `lastAccessTTL`.
    struct Sticky: Codable, Sendable, Equatable {
        /// The sticky ID.
        let id: String
        
        /// Reporting metadata.
        let reportingMetadata: AirshipJSON?

        /// Time to cache the result.
        var lastAccessTTL: TimeInterval

        enum CodingKeys: String, CodingKey {
            case id
            case reportingMetadata = "reporting_metadata"
            case lastAccessTTLMilliseconds = "last_access_ttl"
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(reportingMetadata, forKey: .reportingMetadata)
            try container.encode((lastAccessTTL * 1000.0), forKey: .lastAccessTTLMilliseconds)
        }

        init(id: String, reportingMetadata: AirshipJSON?, lastAccessTTL: TimeInterval) {
            self.id = id
            self.reportingMetadata = reportingMetadata
            self.lastAccessTTL = lastAccessTTL
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            reportingMetadata = try container.decode(AirshipJSON?.self, forKey: .reportingMetadata)
            lastAccessTTL = TimeInterval(try container.decode(Double.self, forKey: .lastAccessTTLMilliseconds)/1000.0)
        }
    }

    func evaluate(channelID: String, contactID: String, date: Date = Date()) -> Bool {
        let param = self.hashParameter(channelID: channelID, contactID: contactID)
        let hash = self.hashFunction(param)
        let result: UInt64 = hash % self.hash.numberOfBuckets
        return self.effectiveBucket(date: date).contains(result)
    }

    /// Resolves the effective audience subset for the given date. Walks `overrides` in order
    /// and returns the first whose schedule is active; otherwise falls back to the base `bucket`.
    private func effectiveBucket(date: Date) -> Bucket {
        guard let overrides else {
            return self.bucket
        }

        for override in overrides where override.schedule.isActive(date: date) {
            return override.resolveBucket(date: date)
        }

        return self.bucket
    }

    private func hashParameter(channelID: String, contactID: String) -> String {
        let property: String = switch self.hash.property {
        case .channel: channelID
        case .contact: contactID
        }

        let resolved: String = self.hash.overrides?[property] ?? property
        return "\(self.hash.prefix)\(resolved)"
    }

    private var hashFunction: (String) -> UInt64 {
        switch(self.hash.algorithm) {
        case .farm:
            return FarmHashFingerprint64.fingerprint
        }
    }
}



