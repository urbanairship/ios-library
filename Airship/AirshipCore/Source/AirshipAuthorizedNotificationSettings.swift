// Copyright Airship and Contributors

import Foundation

import UserNotifications

// Authorized notification settings.
public struct AirshipAuthorizedNotificationSettings: OptionSet, Sendable {
    public let rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    // Badge
    public static let badge = AirshipAuthorizedNotificationSettings(rawValue: 1 << 0)

    // Sound
    public static let sound = AirshipAuthorizedNotificationSettings(rawValue: 1 << 1)

    // Alert
    public static let alert = AirshipAuthorizedNotificationSettings(rawValue: 1 << 2)

    // Carplad
    public static let carPlay = AirshipAuthorizedNotificationSettings(rawValue: 1 << 3)

    // Lockscreen
    public static let lockScreen = AirshipAuthorizedNotificationSettings(rawValue: 1 << 4)

    // Notification Center
    public static let notificationCenter = AirshipAuthorizedNotificationSettings(rawValue: 1 << 5)

    // Critical alert
    public static let criticalAlert = AirshipAuthorizedNotificationSettings(rawValue: 1 << 6)

    // Announcement
    public static let announcement = AirshipAuthorizedNotificationSettings(rawValue: 1 << 7)

    // Scheduled delivery
    public static let scheduledDelivery = AirshipAuthorizedNotificationSettings(rawValue: 1 << 8)

    // Time sensitive
    public static let timeSensitive = AirshipAuthorizedNotificationSettings(rawValue: 1 << 9)
}


extension AirshipAuthorizedNotificationSettings {

    static func from(settings: UNNotificationSettings) -> AirshipAuthorizedNotificationSettings {
        var authorizedSettings: AirshipAuthorizedNotificationSettings = []
#if !os(watchOS)
        if settings.badgeSetting == .enabled {
            authorizedSettings.insert(.badge)
        }
#endif

#if !os(tvOS)

        if settings.soundSetting == .enabled {
            authorizedSettings.insert(.sound)
        }

        if settings.alertSetting == .enabled {
            authorizedSettings.insert(.alert)
        }

#if !os(watchOS)
        if settings.carPlaySetting == .enabled {
            authorizedSettings.insert(.carPlay)
        }

        if settings.lockScreenSetting == .enabled {
            authorizedSettings.insert(.lockScreen)
        }
#endif

        if settings.notificationCenterSetting == .enabled {
            authorizedSettings.insert(.notificationCenter)
        }

        if settings.criticalAlertSetting == .enabled {
            authorizedSettings.insert(.criticalAlert)
        }

#if !os(visionOS)
        /// Announcement authorization is always included in visionOS
        if settings.announcementSetting == .enabled {
            authorizedSettings.insert(.announcement)
        }
#endif

#endif

#if !os(tvOS) && !targetEnvironment(macCatalyst)

        if settings.timeSensitiveSetting == .enabled {
            authorizedSettings.insert(.timeSensitive)
        }

        if settings.scheduledDeliverySetting == .enabled {
            authorizedSettings.insert(.scheduledDelivery)
        }

#endif
        return authorizedSettings
    }
}
