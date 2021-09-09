/* Copyright Airship and Contributors */

/**
 * @note For Interrnal use only :nodoc:
 */
@objc(UAAppInitEvent)
public class AppInitEvent : NSObject, Event {

    private lazy var analytics = Airship.requireComponent(ofType: AnalyticsProtocol.self)

    @objc
    public var priority: UAEventPriority {
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
        data["connection_type"] = Utils.connectionType()

        data["notification_types"] = EventUtils.notificationTypes()
        data["notification_authorization"] = EventUtils.notificationAuthorization()

        let localtz = NSTimeZone.default as NSTimeZone
        data["time_zone"] = NSNumber(value: Double(localtz.secondsFromGMT))
        data["daylight_savings"] = localtz.isDaylightSavingTime ? "true" : "false"

        // Component Versions
        data["os_version"] = UIDevice.current.systemVersion
        data["lib_version"] = AirshipVersion.get()

        let packageVersion = Utils.bundleShortVersionString() ?? ""
        data["package_version"] = packageVersion

        // Foreground
        let isInForeground = AppStateTracker.shared.state != .background
        data["foreground"] = isInForeground ? "true" : "false"

        return data
    }
}
