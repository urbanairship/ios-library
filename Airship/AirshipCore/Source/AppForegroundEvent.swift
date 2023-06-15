/* Copyright Airship and Contributors */

/// - Note: For Internal use only :nodoc:
class AppForegroundEvent: NSObject, AirshipEvent {
    
    private let _data: [AnyHashable: Any]

    @MainActor
    init(
        analytics: AnalyticsProtocol = Airship.requireComponent(ofType: AnalyticsProtocol.self),
        push: PushProtocol = Airship.requireComponent(ofType: PushProtocol.self)
    ) {
        var data = AppInitEvent.gatherData(analytics: analytics, push: push)
        data.removeValue(forKey: "foreground")
        self._data = data
    }

    @objc
    public var priority: EventPriority {
        return .normal
    }

    @objc
    public var eventType: String {
        return "app_foreground"
    }

    @objc
    public var data: [AnyHashable: Any] {
        return self._data
    }
}
