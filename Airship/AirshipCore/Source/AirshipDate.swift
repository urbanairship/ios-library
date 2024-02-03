/* Copyright Airship and Contributors */

import Foundation

/// - Note: For internal use only. :nodoc:
public final class AirshipDate: AirshipDateProtocol {
    public static let shared = AirshipDate()
    public init() {}
    public var now: Date {
        return Date()
    }
}

/// - Note: For internal use only. :nodoc:
public protocol AirshipDateProtocol: Sendable {
    var now: Date { get }
}
