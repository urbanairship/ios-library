/* Copyright Airship and Contributors */

import Foundation

/// - Note: For Internal use only :nodoc:
public enum AirshipEventPriority: Sendable {
    case normal
    case high
}


/// - Note: For Internal use only :nodoc:
public struct AirshipEvent: Sendable {
    public var priority: AirshipEventPriority
    public var eventType: String
    public var eventData: AirshipJSON

    public init(
        priority: AirshipEventPriority = .normal,
        eventType: String,
        eventData: AirshipJSON
    ) {
        self.priority = priority
        self.eventType = eventType
        self.eventData = eventData
    }
}
