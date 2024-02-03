/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

enum InAppEventMessageID: Encodable, Equatable {
    case legacy(identifier: String)
    case airship(identifier: String, campaigns: AirshipJSON?)
    case appDefined(identifier: String)

    enum CodingKeys: String, CodingKey {
        case messageID = "message_id"
        case campaigns
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .legacy(identifier: let identifier):
            var container = encoder.singleValueContainer()
            try container.encode(identifier)
        case .airship(identifier: let identifier, campaigns: let campaigns):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(identifier, forKey: .messageID)
            try container.encodeIfPresent(campaigns, forKey: .campaigns)
        case .appDefined(identifier: let identifier):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(identifier, forKey: .messageID)
        }
    }
    
    var identifier: String {
        switch self {
        case .legacy(let identifier): return identifier
        case .airship(let identifier, _): return identifier
        case .appDefined(let identifier): return identifier
        }
    }
}
