/* Copyright Airship and Contributors */

import Foundation

///Helper class for querying APNS authorization and updating registration.
///For internal use only. :nodoc:
@objc
public class UAAPNSRegistration : NSObject, APNSRegistrationProtocol {
    @objc(getAuthorizedSettingsWithCompletionHandler:)
    public func getAuthorizedSettings(completionHandler: @escaping (UAAuthorizedNotificationSettings, UAAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { [self] notificationSettings in
            let status = uaStatus(notificationSettings.authorizationStatus)
            var authorizedSettings:UAAuthorizedNotificationSettings = []

            if (notificationSettings.badgeSetting == .enabled) {
                authorizedSettings.insert(.badge)
            }

            #if !os(tvOS)
            if notificationSettings.soundSetting == .enabled {
                authorizedSettings.insert(.sound)
            }

            if notificationSettings.alertSetting == .enabled {
                authorizedSettings.insert(.alert)
            }

            if notificationSettings.carPlaySetting == .enabled {
                authorizedSettings.insert(.carPlay)
            }

            if notificationSettings.lockScreenSetting == .enabled {
                authorizedSettings.insert(.lockScreen)
            }

            if notificationSettings.notificationCenterSetting == .enabled {
                authorizedSettings.insert(.notificationCenter)
            }

            if #available(iOS 12.0, *) {
                if notificationSettings.criticalAlertSetting == .enabled {
                    authorizedSettings.insert(.criticalAlert)
                }
            }

            if #available(iOS 13.0, *) {
                if notificationSettings.announcementSetting == .enabled {
                    authorizedSettings.insert(.announcement)
                }
            }

            #endif

            completionHandler(authorizedSettings, status)
        }
    }

    #if !os(tvOS)
    @objc
    public func updateRegistration(options: UANotificationOptions, categories: Set<UNNotificationCategory>, completionHandler: @escaping (Bool, UAAuthorizedNotificationSettings, UAAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().setNotificationCategories(categories)

        self.updateRegistration(options: options, completionHandler: completionHandler)

    }

    #endif

    @objc
    public func updateRegistration(options: UANotificationOptions, completionHandler: @escaping (Bool, UAAuthorizedNotificationSettings, UAAuthorizationStatus) -> Void) {
        let normalizedOptions = self.normalizedOptions(options)
        let center = UNUserNotificationCenter.current()

        center.requestAuthorization(options: normalizedOptions) { granted, error in
            if let error = error  {
                AirshipLogger.error("requestAuthorizationWithOptions failed with error: \(error)")
            }

            self.getAuthorizedSettings { authorizedSettings, status in
                completionHandler(granted, authorizedSettings, status)
            }
        }
    }


    private func normalizedOptions(_ uaOptions:UANotificationOptions) -> UNAuthorizationOptions {
        var unOptions:UNAuthorizationOptions = []

        if uaOptions.contains(.badge) {
            unOptions.insert(.badge)
        }

        if uaOptions.contains(.sound) {
            unOptions.insert(.sound)
        }

        if uaOptions.contains(.alert) {
            unOptions.insert(.alert)
        }

        if uaOptions.contains(.carPlay) {
            unOptions.insert(.carPlay)
        }

        // These authorization options and settings are iOS 12+
        if #available(iOS 12.0, tvOS 12.0, *) {
            if uaOptions.contains(.criticalAlert) {
                unOptions.insert(.criticalAlert)
            }

            if uaOptions.contains(.providesAppNotificationSettings) {
                unOptions.insert(.providesAppNotificationSettings)
            }

            if uaOptions.contains(.provisional) {
                unOptions.insert(.provisional)
            }
        }

        #if !os(tvOS) // UNAuthorizationOptionAnnouncement not supported on tvOS
        // These authorization options and settings are iOS 13+
        if #available(iOS 13.0, *) {
            if uaOptions.contains(.announcement) {
                unOptions.insert(.announcement)
            }
        }
        #endif

        return unOptions
    }

    private func uaStatus(_ status:UNAuthorizationStatus) -> UAAuthorizationStatus {
        if #available(iOS 12.0, tvOS 12.0, *) {
            if status == .provisional {
                return .provisional
            }
        }

        if status == .notDetermined {
            return .notDetermined
        } else if status == .denied {
            return .denied
        } else if status == .authorized {
            return .authorized
        }

        #if !os(tvOS) && !targetEnvironment(macCatalyst)

        if #available(iOS 14.0, *) {
            if (status == .ephemeral) {
                return .ephemeral;
            }
        }
        #endif

        AirshipLogger.warn("Unable to handle UNAuthorizationStatus: \(status.rawValue)")

        return .notDetermined
    }
}
