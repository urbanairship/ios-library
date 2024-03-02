/* Copyright Airship and Contributors */

import Foundation

/// NOTE: For internal use only. :nodoc:
protocol InAppEvent: Sendable {
    var name: String { get }
    var data: (any Sendable&Encodable)? { get }
}

