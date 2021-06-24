/* Copyright Airship and Contributors */

import AirshipCore

@objc(UATestDate)
public class UATestDate : UADate {

    @objc
    public init(offset : TimeInterval, dateOverride: Date?) {
        self.offset = offset
        self.dateOverride = dateOverride
        super.init()
    }
    @objc
    public override convenience init() {
        self.init(offset: 0, dateOverride: nil)
    }

    @objc
    public var offset : TimeInterval

    @objc
    public var dateOverride : Date?

    public override var now: Date {
        get {
            let date = dateOverride ?? Date()
            return date.addingTimeInterval(offset)
        }
    }


}
