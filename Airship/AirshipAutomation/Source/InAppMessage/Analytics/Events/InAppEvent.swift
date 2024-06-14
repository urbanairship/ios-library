/* Copyright Airship and Contributors */

import Foundation
#if canImport(AirshipCore)
import AirshipCore
#endif

/// NOTE: For internal use only. :nodoc:
protocol InAppEvent: Sendable {
    var name: EventType { get }
    var data: (any Sendable&Encodable)? { get }
}

