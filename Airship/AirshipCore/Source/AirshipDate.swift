/* Copyright Airship and Contributors */

import Foundation

/// - Note: For internal use only. :nodoc:
@objc(UAirshipDate)
public final class AirshipDate: NSObject, AirshipDateProtocol {

    @objc
    public static let shared = AirshipDate()

    @objc
    public override init() {
        super.init()
    }

    @objc
    public var now: Date {
        return Date()
    }
}

/// - Note: For internal use only. :nodoc:
public protocol AirshipDateProtocol: Sendable {
    var now: Date { get }
}
