/* Copyright Airship and Contributors */

import Foundation

/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public struct AirshipTriggerContext: Codable, Sendable, Equatable {
    let type: String
    let goal: Double
    let event: AirshipJSON

    public init(type: String, goal: Double, event: AirshipJSON) {
        self.type = type
        self.goal = goal
        self.event = event
    }
}
