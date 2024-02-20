/* Copyright Airship and Contributors */

@testable
import AirshipCore

public class UATestDate: @unchecked Sendable, AirshipDateProtocol  {

    public init(offset: TimeInterval = 0, dateOverride: Date? = nil) {
        self._offSet = Atomic(offset)
        self.dateOverride = dateOverride
    }

    private var _offSet: Atomic<TimeInterval>

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
        return date.addingTimeInterval(offset)
    }

}
