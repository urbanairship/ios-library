/* Copyright Airship and Contributors */

import Foundation
import AirshipBasement

struct ThomasAutomatedAction: Codable, Equatable, Sendable {
    var identifier: String
    var delay: Double?
    var actions: [ThomasActionsPayload]?
    var behaviors: [ThomasButtonClickBehavior]?
    var reportingMetadata: AirshipJSON?
    /// If defined, `behaviors` and `actions` will be ignored.
    var outcomes: [ThomasOutcome]?


    enum CodingKeys: String, CodingKey {
        case identifier
        case delay
        case actions
        case behaviors
        case reportingMetadata = "reporting_metadata"
        case outcomes
    }
}
