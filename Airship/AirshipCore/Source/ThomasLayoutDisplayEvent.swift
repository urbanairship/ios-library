/* Copyright Airship and Contributors */

import Foundation

/// NOTE: For internal use only. :nodoc:
public struct ThomasLayoutDisplayEvent: ThomasLayoutEvent {
    public let name = EventType.inAppDisplay
    public let data: (any Sendable & Encodable)? = nil
    
    public init() {}
}
