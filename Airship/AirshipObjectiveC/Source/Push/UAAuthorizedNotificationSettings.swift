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
    public static func badge() -> UAAuthorizedNotificationSettings {
        return UAAuthorizedNotificationSettings(rawValue: AirshipAuthorizedNotificationSettings.badge.rawValue)
    }

    // Sound
    @objc
    public static func sound() -> UAAuthorizedNotificationSettings {
        return UAAuthorizedNotificationSettings(rawValue: AirshipAuthorizedNotificationSettings.sound.rawValue)
    }

    // Alert
    @objc
    public static func alert() -> UAAuthorizedNotificationSettings {
        return UAAuthorizedNotificationSettings(rawValue: AirshipAuthorizedNotificationSettings.alert.rawValue)
    }

    // Car Play
    @objc
    public static func carPlay() -> UAAuthorizedNotificationSettings {
        return UAAuthorizedNotificationSettings(rawValue: AirshipAuthorizedNotificationSettings.carPlay.rawValue)
    }

    // Lock Screen
    @objc
    public static func lockScreen() -> UAAuthorizedNotificationSettings {
        return UAAuthorizedNotificationSettings(rawValue: AirshipAuthorizedNotificationSettings.lockScreen.rawValue)
    }

    // Notification Center
    @objc
    public static func notificationCenter() -> UAAuthorizedNotificationSettings {
        return UAAuthorizedNotificationSettings(rawValue: AirshipAuthorizedNotificationSettings.notificationCenter.rawValue)
    }

    // Critical alert
    @objc
    public static func criticalAlert() -> UAAuthorizedNotificationSettings {
        return UAAuthorizedNotificationSettings(rawValue: AirshipAuthorizedNotificationSettings.criticalAlert.rawValue)
    }

    // Announcement
    @objc
    public static func announcement() -> UAAuthorizedNotificationSettings {
        return UAAuthorizedNotificationSettings(rawValue: AirshipAuthorizedNotificationSettings.announcement.rawValue)
    }

    // Scheduled delivery
    @objc
    public static func scheduledDelivery() -> UAAuthorizedNotificationSettings {
        return UAAuthorizedNotificationSettings(rawValue: AirshipAuthorizedNotificationSettings.scheduledDelivery.rawValue)
    }

    // Time sensitive
    @objc
    public static func timeSensitive() -> UAAuthorizedNotificationSettings {
        return UAAuthorizedNotificationSettings(rawValue: AirshipAuthorizedNotificationSettings.timeSensitive.rawValue)
    }
    
    public override var hash: Int {
        return Int(rawValue)
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let that = object as? UAAuthorizedNotificationSettings else {
            return false
        }

        return rawValue == that.rawValue
    }
}

extension AirshipAuthorizedNotificationSettings {
    var asUAAuthorizedNotificationSettings: UAAuthorizedNotificationSettings {
        return UAAuthorizedNotificationSettings(rawValue: self.rawValue)
    }
}
