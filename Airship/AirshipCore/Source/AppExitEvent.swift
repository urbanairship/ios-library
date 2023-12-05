/* Copyright Airship and Contributors */

/// - Note: For Internal use only :nodoc:
class AppExitEvent: NSObject, AirshipEvent {
    private let _data: [AnyHashable: Any]

    init(sessionState: SessionState) {
        self._data = Self.gatherData(sessionState: sessionState)
    }

    @objc
    public var priority: EventPriority {
        return .normal
    }

    @objc
    public var eventType: String {
        return "app_exit"
    }

   
    @objc
    public var data: [AnyHashable: Any] {
        return self._data
    }

    private static func gatherData(sessionState: SessionState) -> [AnyHashable: Any] {
        var data: [AnyHashable: Any] = [:]

        data["push_id"] = sessionState.conversionSendID
        data["metadata"] = sessionState.conversionMetadata
        #if !os(watchOS)
        data["connection_type"] = AirshipUtils.connectionType()
        #endif

        return data
    }

}
