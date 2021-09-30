/* Copyright Airship and Contributors */

/**
 * - Note: For Internal use only :nodoc:
 */
@objc(UAScreenTrackingEvent)
class ScreenTrackingEvent : NSObject, Event {

    private let _data : [String : Any]

    @objc
    public let screen : String;

    @objc
    public let previousScreen : String?;

    @objc
    public let startTime : TimeInterval;

    @objc
    public let stopTime : TimeInterval;

    @objc
    public var eventType : String {
        get {
            return "screen_tracking"
        }
    }

    @objc
    public var data: [AnyHashable : Any] {
        get {
            return self._data
        }
    }

    @objc
    public var priority: EventPriority {
        get {
            return .normal
        }
    }

    @objc
    public init?(screen: String,
                 previousScreen: String?,
                 startTime: TimeInterval,
                 stopTime: TimeInterval) {

        guard stopTime > startTime else {
            AirshipLogger.error("Stop time must be after start time.")
            return nil
        }

        guard ScreenTrackingEvent.isValid(screen: screen) else {
            return nil
        }

        var data : [String : Any] = [:]
        data["screen"] = screen
        data["previous_screen"] = previousScreen
        data["entered_time"] = String(format: "%0.3f", startTime)
        data["exited_time"] = String(format: "%0.3f", stopTime)
        data["duration"] = String(format: "%0.3f", stopTime - startTime)

        self._data = data
        self.screen = screen
        self.previousScreen = previousScreen
        self.startTime = startTime
        self.stopTime = stopTime
    }

    private class func isValid(screen: String) -> Bool {
        guard screen.count >= 1 && screen.count <= 255 else {
            AirshipLogger.error("Invalid screen \(screen). Must be between 1 and 255 characters")
            return false
        }
        return true
    }
}
