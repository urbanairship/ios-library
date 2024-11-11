/* Copyright Airship and Contributors */

import Foundation

struct ThomasAccessibilityAction: ThomasSerailizable {

    enum ActionType: String, ThomasSerailizable {
        case `default` = "default"
        case escape = "escape"
    }

    struct Properties: ThomasSerailizable {
        var type: ActionType
        var reportingMetadata: AirshipJSON?
        var actions: [ThomasActionsPayload]?
        var behaviors: [ThomasButtonClickBehavior]?

        enum CodingKeys: String, CodingKey {
            case type
            case reportingMetadata = "reporting_metadata"
            case actions
            case behaviors
        }
    }

    var accessible: ThomasAccessibleInfo
    var properties: Properties

    func encode(to encoder: any Encoder) throws {
        try accessible.encode(to: encoder)
        try properties.encode(to: encoder)
    }

    init(from decoder: any Decoder) throws {
        self.accessible = try ThomasAccessibleInfo(from: decoder)
        self.properties = try Properties(from: decoder)
    }
}
