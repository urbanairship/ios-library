/* Copyright Airship and Contributors */

import Foundation

/// NOTE: For internal use only. :nodoc:
struct AudienceHashSelector: Codable, Sendable, Equatable {
    let hash: Hash
    let bucket: Bucket
    
    enum CodingKeys: String, CodingKey {
        case hash = "audience_hash"
        case bucket = "audience_subset"
    }

    struct Hash: Codable, Sendable, Equatable {
        enum Identifier: String, Codable, Equatable {
            case channel, contact
        }

        enum Algorightm: String, Codable, Equatable {
            case farm = "farm_hash"
        }

        let prefix: String
        let property: Identifier
        let algorithm: Algorightm
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
    

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.min = try container.decodeIfPresent(UInt64.self, forKey: .min) ?? 0
            self.max = try container.decodeIfPresent(UInt64.self, forKey: .max) ?? UInt64.max
        }

        func contains(_ value: UInt64) -> Bool {
            return value >= min && value <= max
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



