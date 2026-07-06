/* Copyright Airship and Contributors */

import Foundation

/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public enum AirshipEventPriority: Sendable {
    case normal
    case high
}


/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public struct AirshipEvent: Sendable {
    public var priority: AirshipEventPriority
    public var eventType: AirshipEventType
    public var eventData: AirshipJSON

    public init(
        priority: AirshipEventPriority = .normal,
        eventType: AirshipEventType,
        eventData: AirshipJSON
    ) {
        self.priority = priority
        self.eventType = eventType
        self.eventData = eventData
    }
}
