/* Copyright Airship and Contributors */

import Foundation
public import AirshipCore

/// - Note: For internal use only. :nodoc:
public protocol ThomasLayoutEvent: Sendable {
    var name: AirshipEventType { get }
    var data: (any Sendable&Encodable)? { get }
}

extension ThomasLayoutEvent {
    var bodyJSON: AirshipJSON {
        get throws {
            try AirshipJSON.wrap(data)
        }
    }
}
