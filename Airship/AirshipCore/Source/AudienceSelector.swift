/* Copyright Airship and Contributors */

import Foundation

struct AudienceSelector: Codable, Sendable {
    let hash: AudienceHash
    let bucket: Bucket
    
    enum CodingKeys: String, CodingKey {
        case hash = "audience_hash"
        case bucket = "audience_subset"
    }
    
    enum WrapperKeys: String, CodingKey {
        case wrapper = "hash"
    }
    
    init(from decoder: Decoder) throws {
        let wrapper = try decoder.container(keyedBy: WrapperKeys.self)
        
        let container = try wrapper.nestedContainer(keyedBy: CodingKeys.self, forKey: .wrapper)
        self.hash = try container.decode(AudienceHash.self, forKey: .hash)
        self.bucket = try container.decode(Bucket.self, forKey: .bucket)
    }
}

struct AudienceHash: Codable, Sendable {
    enum Identifier: String, Codable {
        case channel, contact
    }
    
    enum Algorightm: String, Codable {
        case farm = "farm_hash"
    }
    
    let prefix: String
    let property: Identifier
    let algorithm: Algorightm
    let seed: UInt?
    let numberOfBuckets: Int
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

struct Bucket: Codable, Sendable {
    let min: UInt
    let max: UInt
    
    enum CodingKeys: String, CodingKey {
        case min = "min_hash_bucket"
        case max = "max_hash_bucket"
    }
}