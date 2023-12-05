/* Copyright Airship and Contributors */

/// - Note: For Internal use only :nodoc:
class AppForegroundEvent: NSObject, AirshipEvent {
    
    private let _data: [AnyHashable: Any]

    @MainActor
    init(
        sessionState: SessionState,
        push: PushProtocol = Airship.requireComponent(ofType: PushProtocol.self)
    ) {
        self._data = AppInitEvent.gatherData(sessionState: sessionState, push: push)
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
