/* Copyright Airship and Contributors */

@testable
public import AirshipCore

public class UATestDate: @unchecked Sendable, AirshipDateProtocol  {

    public init(offset: TimeInterval = 0, dateOverride: Date? = nil) {
        self._offSet = AirshipAtomicValue(offset)
        self.dateOverride = dateOverride
    }

    private var _offSet: AirshipAtomicValue<TimeInterval>

    public func advance(by: TimeInterval) {
        self._offSet.value += by
    }

    public var offset: TimeInterval {
        get {
            return self._offSet.value
        }
        set {
            self._offSet.value = newValue
        }
    }

    public var dateOverride: Date?

    public var now: Date {
        let date = dateOverride ?? Date()
        return date.advanced(by: offset)
    }
}

