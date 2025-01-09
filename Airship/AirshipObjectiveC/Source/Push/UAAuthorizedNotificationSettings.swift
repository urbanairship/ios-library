/* Copyright Airship and Contributors */

public import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif


// Authorized notification settings.
@objc
public final class UAAuthorizedNotificationSettings: NSObject, OptionSet, Sendable {
    public let rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    // Badge
    @objc
    public static let badge = UAAuthorizedNotificationSettings(
        rawValue: AirshipAuthorizedNotificationSettings.badge.rawValue
    )

    // Sound
    @objc
    public static let sound = UAAuthorizedNotificationSettings(
        rawValue: AirshipAuthorizedNotificationSettings.sound.rawValue
    )

    // Alert
    @objc
    public static let alert = UAAuthorizedNotificationSettings(
        rawValue: AirshipAuthorizedNotificationSettings.alert.rawValue
    )

    // Car Play
    @objc
    public static let carPlay = UAAuthorizedNotificationSettings(
        rawValue: AirshipAuthorizedNotificationSettings.carPlay.rawValue
    )

    // Lock Screen
    @objc
    public static let lockScreen = UAAuthorizedNotificationSettings(
        rawValue: AirshipAuthorizedNotificationSettings.lockScreen.rawValue
    )

    // Notification Center
    @objc
    public static let notificationCenter = UAAuthorizedNotificationSettings(
        rawValue: AirshipAuthorizedNotificationSettings.notificationCenter.rawValue
    )

    // Critical alert
    @objc
    public static let criticalAlert = UAAuthorizedNotificationSettings(
        rawValue: AirshipAuthorizedNotificationSettings.criticalAlert.rawValue
    )

    // Announcement
    @objc
    public static let announcement = UAAuthorizedNotificationSettings(
        rawValue: AirshipAuthorizedNotificationSettings.announcement.rawValue
    )

    // Scheduled delivery
    @objc
    public static let scheduledDelivery = UAAuthorizedNotificationSettings(
        rawValue: AirshipAuthorizedNotificationSettings.scheduledDelivery.rawValue
    )

    // Time sensitive
    @objc
    public static let timeSensitive = UAAuthorizedNotificationSettings(
        rawValue: AirshipAuthorizedNotificationSettings.timeSensitive.rawValue
    )
}

extension AirshipAuthorizedNotificationSettings {
    var asUAAuthorizedNotificationSettings: UAAuthorizedNotificationSettings {
        return UAAuthorizedNotificationSettings(rawValue: self.rawValue)
    }
}
