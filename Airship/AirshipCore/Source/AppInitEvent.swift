/* Copyright Airship and Contributors */

/**
 * - Note: For Internal use only :nodoc:
 */
class AppInitEvent : NSObject, Event {

    private lazy var analytics = Airship.requireComponent(ofType: AnalyticsProtocol.self)
    private lazy var push: () -> PushProtocol = { Airship.push }
    
    convenience init(analytics: AnalyticsProtocol, push: @escaping () -> PushProtocol) {
        self.init()
        self.analytics = analytics
        self.push = push
    }
    
    @objc
    public var priority: EventPriority {
        get {
            return .normal
        }
    }
    
    @objc
    public var eventType : String {
        get {
            return "app_init"
        }
    }

    @objc
    public var data: [AnyHashable : Any] {
        get {
            return self.gatherData()
        }
    }
    open func gatherData() -> [AnyHashable : Any] {
        var data: [AnyHashable : Any] = [:]

        data["push_id"] = self.analytics.conversionSendID
        data["metadata"] = self.analytics.conversionPushMetadata
        data["carrier"] = Utils.carrierName()
        #if !os(watchOS)
        data["connection_type"] = Utils.connectionType()
        #endif

        data["notification_types"] = EventUtils.notificationTypes(authorizedSettings: push().authorizedNotificationSettings)
        data["notification_authorization"] = EventUtils.notificationAuthorization(authorizationStatus: push().authorizationStatus)

        let localtz = NSTimeZone.default as NSTimeZone
        data["time_zone"] = NSNumber(value: Double(localtz.secondsFromGMT))
        data["daylight_savings"] = localtz.isDaylightSavingTime ? "true" : "false"

        // Component Versions
        #if !os(watchOS)
        data["os_version"] = UIDevice.current.systemVersion
        #else
        data["os_version"] = WKInterfaceDevice.current().systemVersion
        #endif
        data["lib_version"] = AirshipVersion.get()

        let packageVersion = Utils.bundleShortVersionString() ?? ""
        data["package_version"] = packageVersion

        // Foreground
        let isInForeground = AppStateTracker.shared.state != .background
        data["foreground"] = isInForeground ? "true" : "false"

        return data
    }
}
