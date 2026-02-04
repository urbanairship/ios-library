/* Copyright Airship and Contributors */

import Foundation

/// - Note: For internal use only. :nodoc:
public final class AirshipDate: AirshipDateProtocol {
    public static let shared: AirshipDate = AirshipDate()
    public init() {}
    public var now: Date {
        return Date()
    }
}

/// - Note: For internal use only. :nodoc:
public protocol AirshipDateProtocol: Sendable {
    var now: Date { get }
}


extension Date {
    var millisecondsSince1970: Int64 {
        Int64((self.timeIntervalSince1970 * 1000.0).rounded())
    }

    init(milliseconds: Int64) {
        self = Date(timeIntervalSince1970: TimeInterval(milliseconds / 1000))
    }
}
