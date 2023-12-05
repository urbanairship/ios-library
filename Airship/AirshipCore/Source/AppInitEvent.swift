/* Copyright Airship and Contributors */

/// - Note: For Internal use only :nodoc:
final class AppInitEvent: NSObject, AirshipEvent {

    private let _data: [AnyHashable: Any]

    @MainActor
    init(
        isForeground: Bool,
        sessionState: SessionState,
        push: PushProtocol = Airship.requireComponent(ofType: PushProtocol.self)
    ) {
        self._data = AppInitEvent.gatherData(sessionState: sessionState, push: push, isForeground: isForeground)
    }

    @objc
    public var priority: EventPriority {
        return .normal
    }

    @objc
    public var eventType: String {
        return "app_init"
    }

    @objc
    public var data: [AnyHashable: Any] {
        return self._data
    }
    
    @MainActor
    static func gatherData(
        sessionState: SessionState,
        push: PushProtocol,
        isForeground: Bool? = nil
    ) -> [AnyHashable: Any] {
        var data: [AnyHashable: Any] = [:]

        data["push_id"] = sessionState.conversionSendID
        data["metadata"] = sessionState.conversionMetadata
        data["carrier"] = AirshipUtils.carrierName()
        #if !os(watchOS)
        data["connection_type"] = AirshipUtils.connectionType()
        #endif

        data["notification_types"] = EventUtils.notificationTypes(
            authorizedSettings: push.authorizedNotificationSettings
        )
        data["notification_authorization"] =
            EventUtils.notificationAuthorization(
                authorizationStatus: push.authorizationStatus
            )

        let localtz = NSTimeZone.default as NSTimeZone
        data["time_zone"] = NSNumber(value: Double(localtz.secondsFromGMT))
        data["daylight_savings"] =
            localtz.isDaylightSavingTime ? "true" : "false"

        // Component Versions
        #if !os(watchOS)
        data["os_version"] = UIDevice.current.systemVersion
        #else
        data["os_version"] = WKInterfaceDevice.current().systemVersion
        #endif
        data["lib_version"] = AirshipVersion.get()

        let packageVersion = AirshipUtils.bundleShortVersionString() ?? ""
        data["package_version"] = packageVersion

        // Foreground
        if let isForeground = isForeground {
            data["foreground"] = isForeground ? "true" : "false"
        }


        return data
    }
}
