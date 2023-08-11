// Copyright Airship and Contributors

import Foundation
@preconcurrency import UserNotifications

/// UNNotificationCenter notification registrar
struct UNNotificationRegistrar: NotificationRegistrar {

    #if !os(tvOS)
    @MainActor
    func setCategories(_ categories: Set<UNNotificationCategory>) {
        UNUserNotificationCenter.current()
            .setNotificationCategories(categories)
    }
    #endif

    @MainActor
    func checkStatus() async -> (UAAuthorizationStatus, UAAuthorizedNotificationSettings) {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return (settings.authorizationStatus.airshipStatus, settings.airshipSettings)
    }

    func updateRegistration(
        options: UANotificationOptions,
        skipIfEphemeral: Bool
    ) async -> Void {

        let requestOptions = options.appleOptions
        let (status, settings) = await checkStatus()

        // Skip registration if no options are enable and we are requesting no options
        if settings == [] && requestOptions == [] {
            return
        }

        // Skip registration for ephemeral if skipRegistrationIfEphemeral
        if status == .ephemeral && skipIfEphemeral {
            return
        }

        var granted = false
        // Request
        do {
            granted = try await UNUserNotificationCenter.current().requestAuthorization(options: options.appleOptions)
        } catch {
            AirshipLogger.error(
                "requestAuthorizationWithOptions failed with error: \(error)"
            )
        }
        AirshipLogger.debug(
            "requestAuthorizationWithOptions \(granted)"
        )
    }
}

extension UNAuthorizationStatus {
    fileprivate var airshipStatus: UAAuthorizationStatus {
        if #available(iOS 12.0, tvOS 12.0, *) {
            if self == .provisional {
                return .provisional
            }
        }

        if self == .notDetermined {
            return .notDetermined
        } else if self == .denied {
            return .denied
        } else if self == .authorized {
            return .authorized
        }

        #if !os(tvOS) && !os(watchOS) && !targetEnvironment(macCatalyst)
        if self == .ephemeral {
            return .ephemeral
        }
        #endif

        AirshipLogger.warn(
            "Unable to handle UNAuthorizationStatus: \(self.rawValue)"
        )
        return .notDetermined
    }
}

extension UNNotificationSettings {
    fileprivate var airshipSettings: UAAuthorizedNotificationSettings {
        var authorizedSettings: UAAuthorizedNotificationSettings = []
        #if !os(watchOS)
        if self.badgeSetting == .enabled {
            authorizedSettings.insert(.badge)
        }
        #endif

        #if !os(tvOS)

        if self.soundSetting == .enabled {
            authorizedSettings.insert(.sound)
        }

        if self.alertSetting == .enabled {
            authorizedSettings.insert(.alert)
        }

        #if !os(watchOS)
        if self.carPlaySetting == .enabled {
            authorizedSettings.insert(.carPlay)
        }

        if self.lockScreenSetting == .enabled {
            authorizedSettings.insert(.lockScreen)
        }
        #endif

        if self.notificationCenterSetting == .enabled {
            authorizedSettings.insert(.notificationCenter)
        }

        if #available(iOS 12.0, *) {
            if self.criticalAlertSetting == .enabled {
                authorizedSettings.insert(.criticalAlert)
            }
        }

        if self.announcementSetting == .enabled {
            authorizedSettings.insert(.announcement)
        }
        #endif

        if #available(iOS 15.0, watchOS 8.0, *) {
            #if !os(tvOS) && !targetEnvironment(macCatalyst)

            if self.timeSensitiveSetting == .enabled {
                authorizedSettings.insert(.timeSensitive)
            }

            if self.scheduledDeliverySetting == .enabled {
                authorizedSettings.insert(.scheduledDelivery)
            }

            #endif
        } else {
            // Fallback on earlier versions
        }
        return authorizedSettings
    }
}

extension UANotificationOptions {
    fileprivate var appleOptions: UNAuthorizationOptions {
        var authorizedOptions: UNAuthorizationOptions = []

        if self.contains(.badge) {
            authorizedOptions.insert(.badge)
        }

        if self.contains(.sound) {
            authorizedOptions.insert(.sound)
        }

        if self.contains(.alert) {
            authorizedOptions.insert(.alert)
        }

        if self.contains(.carPlay) {
            authorizedOptions.insert(.carPlay)
        }

        if #available(iOS 12.0, tvOS 12.0, *) {
            if self.contains(.criticalAlert) {
                authorizedOptions.insert(.criticalAlert)
            }

            if self.contains(.providesAppNotificationSettings) {
                authorizedOptions.insert(.providesAppNotificationSettings)
            }

            if self.contains(.provisional) {
                authorizedOptions.insert(.provisional)
            }
        }

        #if !os(tvOS) && !os(watchOS)
        // Avoids deprecation warning
        let annoucement = UANotificationOptions(rawValue: (1 << 7))
        if self.contains(annoucement) {
            authorizedOptions.insert(.announcement)
        }
        #endif

        return authorizedOptions
    }
}
