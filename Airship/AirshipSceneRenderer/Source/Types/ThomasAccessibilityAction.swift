/* Copyright Airship and Contributors */

import Foundation
import AirshipBasement

struct ThomasAccessibilityAction: ThomasSerializable {

    enum ActionType: String, ThomasSerializable {
        case `default` = "default"
        case escape = "escape"
    }

    struct Properties: ThomasSerializable {
        var type: ActionType
        var reportingMetadata: AirshipJSON?
        var actions: [ThomasActionsPayload]?
        var behaviors: [ThomasButtonClickBehavior]?
        /// If defined, `behaviors` and `actions` will be ignored.
        var outcomes: [ThomasOutcome]?

        enum CodingKeys: String, CodingKey {
            case type
            case reportingMetadata = "reporting_metadata"
            case actions
            case behaviors
            case outcomes
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
