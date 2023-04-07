/* Copyright Airship and Contributors */

@testable
import AirshipCore

@objc(UATestDate)
public class UATestDate: NSObject, @unchecked Sendable, AirshipDateProtocol  {

    @objc
    public init(offset: TimeInterval, dateOverride: Date?) {
        self._offSet = Atomic(offset)
        self.dateOverride = dateOverride
        super.init()
    }
    @objc
    public override convenience init() {
        self.init(offset: 0, dateOverride: nil)
    }

    private var _offSet: Atomic<TimeInterval>

    @objc
    public var offset: TimeInterval {
        get {
            return self._offSet.value
        }

        set {
            self._offSet.value = newValue
        }
    }

    @objc
    public var dateOverride: Date?

    @objc
    public var now: Date {
        let date = dateOverride ?? Date()
        return date.addingTimeInterval(offset)
    }

}
