/* Copyright Airship and Contributors */

public import Foundation

/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public final class AirshipDate: AirshipDateProtocol {
    public static let shared: AirshipDate = AirshipDate()
    public init() {}
    public var now: Date {
        return Date()
    }
}

/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public protocol AirshipDateProtocol: Sendable {
    var now: Date { get }
}


@_spi(AirshipInternal)
public extension Date {
    var airshipMillisecondsSince1970: Int64 {
        Int64((self.timeIntervalSince1970 * 1000.0).rounded())
    }

    init(airshipMilliseconds: Int64) {
        self = Date(timeIntervalSince1970: TimeInterval(airshipMilliseconds / 1000))
    }
}
