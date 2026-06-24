/* Copyright Airship and Contributors */

import Foundation
public import AirshipCore


/// - Note: For internal use only. :nodoc:
public struct ThomasLayoutDisplayEvent: ThomasLayoutEvent {
    public let name: EventType = EventType.inAppDisplay
    public let data: (any Sendable & Encodable)? = nil
    
    public init() {}
}
