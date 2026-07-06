/* Copyright Airship and Contributors */

@_spi(AirshipInternal) import AirshipSceneRenderer
import Foundation
import AirshipCore
public import AirshipBasement

/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public enum ThomasLayoutEventMessageID: Encodable, Equatable, Sendable {
    case legacy(identifier: String)
    case airship(identifier: String, campaigns: AirshipJSON?, sendMetadata: String? = nil)
    case appDefined(identifier: String)

    enum CodingKeys: String, CodingKey {
        case messageID = "message_id"
        case campaigns
        case sendMetadata = "com.urbanairship.metadata"
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .legacy(identifier: let identifier):
            var container = encoder.singleValueContainer()
            try container.encode(identifier)
        case .airship(identifier: let identifier, campaigns: let campaigns, sendMetadata: let sendMetadata):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(identifier, forKey: .messageID)
            try container.encodeIfPresent(campaigns, forKey: .campaigns)
            try container.encodeIfPresent(sendMetadata, forKey: .sendMetadata)
        case .appDefined(identifier: let identifier):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(identifier, forKey: .messageID)
        }
    }
    
    public var identifier: String {
        switch self {
        case .legacy(let identifier): return identifier
        case .airship(let identifier, _, _): return identifier
        case .appDefined(let identifier): return identifier
        }
    }
}
