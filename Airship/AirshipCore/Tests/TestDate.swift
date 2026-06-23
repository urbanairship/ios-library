/* Copyright Airship and Contributors */

public import Foundation
@_spi(AirshipInternal) public import AirshipBasement

@_spi(AirshipInternal)
public class UATestDate: @unchecked Sendable, AirshipDateProtocol  {

    public init(offset: TimeInterval = 0, dateOverride: Date? = nil) {
        self._offSet = offset
        self.dateOverride = dateOverride
    }

    private let lock = NSLock()
    private var _offSet: TimeInterval

    public func advance(by: TimeInterval) {
        self.offset += by
    }

    public var offset: TimeInterval {
        get {
            return self.lock.withLock { self._offSet }
        }
        set {
            self.lock.withLock { self._offSet = newValue }
        }
    }

    public var dateOverride: Date?

    public var now: Date {
        let date = dateOverride ?? Date()
        return date.advanced(by: offset)
    }
}

