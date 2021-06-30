/* Copyright Airship and Contributors */

/**
 * @note For Interrnal use only :nodoc:
 */
@objc
public class UAAppInitEvent : NSObject, UAEvent {

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

        let analytics = UAirship.analytics()

        data["push_id"] = analytics?.conversionSendID
        data["metadata"] = analytics?.conversionPushMetadata
        data["carrier"] = UAUtils.carrierName()
        data["connection_type"] = UAUtils.connectionType()

        data["notification_types"] = UAEventUtils.notificationTypes()
        data["notification_authorization"] = UAEventUtils.notificationAuthorization()

        let localtz = NSTimeZone.default as NSTimeZone
        data["time_zone"] = NSNumber(value: Double(localtz.secondsFromGMT))
        data["daylight_savings"] = localtz.isDaylightSavingTime ? "true" : "false"

        // Component Versions
        data["os_version"] = UIDevice.current.systemVersion
        data["lib_version"] = UAirshipVersion.get()

        let packageVersion = UAUtils.bundleShortVersionString() ?? ""
        data["package_version"] = packageVersion

        // Foreground
        let isInForeground = UAAppStateTracker.shared.state != .background
        data["foreground"] = isInForeground ? "true" : "false"

        return data
    }
}
