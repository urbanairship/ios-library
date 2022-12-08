/* Copyright Airship and Contributors */

/// - Note: For Internal use only :nodoc:
class ScreenTrackingEvent: NSObject, Event {

    private let _data: [String: Any]

    @objc
    public var eventType: String {
        return "screen_tracking"
    }

    @objc
    public var data: [AnyHashable: Any] {
        return self._data
    }

    @objc
    public var priority: EventPriority {
        return .normal
    }

    init?(
        screen: String,
        previousScreen: String?,
        startDate: Date,
        duration: TimeInterval
    ) {

        guard duration > 0 else {
            AirshipLogger.error(
                "Invalid screen \(screen). Duration is zero"
            )
            return nil
        }
        
        guard screen.count >= 1,
              screen.count <= 255
        else {
            AirshipLogger.error(
                "Invalid screen \(screen). Must be between 1 and 255 characters"
            )
            return nil
        }

        var data: [String: Any] = [:]
        data["screen"] = screen
        data["previous_screen"] = previousScreen

        data["entered_time"] = String(
            format: "%0.3f",
            startDate.timeIntervalSince1970
        )

        data["exited_time"] = String(
            format: "%0.3f",
            startDate.addingTimeInterval(duration).timeIntervalSince1970
        )

        data["duration"] = String(
            format: "%0.3f", duration
        )

        self._data = data
    }
}
