/* Copyright Airship and Contributors */

import Foundation

/// NOTE: For internal use only. :nodoc:
public struct AirshipTriggerContext: Encodable, Sendable, Equatable {
    let type: String
    let goal: Double
    let event: AirshipJSON

    public init(type: String, goal: Double, event: AirshipJSON) {
        self.type = type
        self.goal = goal
        self.event = event
    }
}
