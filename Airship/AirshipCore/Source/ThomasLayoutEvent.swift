/* Copyright Airship and Contributors */

import Foundation

/// NOTE: For internal use only. :nodoc:
public protocol ThomasLayoutEvent: Sendable {
    var name: EventType { get }
    var data: (any Sendable&Encodable)? { get }
}
