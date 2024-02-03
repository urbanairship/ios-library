/* Copyright Airship and Contributors */

import Foundation

protocol InAppEvent: Sendable {
    var name: String { get }
    var data: (any Sendable&Encodable)? { get }
}

