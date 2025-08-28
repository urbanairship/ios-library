/* Copyright Airship and Contributors */

/// NOTE: For internal use only. :nodoc:
public struct AudienceHashSelector: Codable, Sendable, Equatable {
    let hash: Hash
    let bucket: Bucket
    var sticky: Sticky?

    init(hash: Hash, bucket: Bucket, sticky: Sticky? = nil) {
        self.hash = hash
        self.bucket = bucket
        self.sticky = sticky
    }
    
    enum CodingKeys: String, CodingKey {
        case hash = "audience_hash"
        case bucket = "audience_subset"
        case sticky
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

    func evaluate(channelID: String, contactID: String) -> Bool {
        let param = self.hashParameter(channelID: channelID, contactID: contactID)
        let hash = self.hashFunction(param)
        let result: UInt64 = hash % self.hash.numberOfBuckets
        return bucket.contains(result)
    }

    private func hashParameter(channelID: String, contactID: String) -> String {
        var property: String!
        switch(self.hash.property) {
        case .channel:
            property = channelID
        case .contact:
            property = contactID
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



