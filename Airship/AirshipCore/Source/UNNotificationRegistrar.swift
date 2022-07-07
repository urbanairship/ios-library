// Copyright Airship and Contributors

import Foundation


/// UNNotificationCenter notification registrar
struct UNNotificationRegistrar: NotificationRegistrar {

#if !os(tvOS)
    func setCategories(_ categories: Set<UNNotificationCategory>) {
        UNUserNotificationCenter.current().setNotificationCategories(categories)
    }
#endif

    func checkStatus(completionHandler: @escaping (UAAuthorizationStatus, UAAuthorizedNotificationSettings) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            completionHandler(settings.authorizationStatus.airshipStatus, settings.airshipSettings)
        }
    }

    func updateRegistration(options: UANotificationOptions,
                            skipIfEphemeral: Bool,
                            completionHandler: @escaping () -> Void) {

        let requestOptions = options.appleOptions
        checkStatus { status, settings in

            // Skip registration if no options are enable dand we are requestion no options
            if (settings == [] && requestOptions == []) {
                completionHandler()
                return
            }


            // Skip registration for ephemeral if skipRegistrationIfEphemeral
            if (status == .ephemeral && skipIfEphemeral) {
                completionHandler()
                return
            }

            // Request
            UNUserNotificationCenter.current().requestAuthorization(options: options.appleOptions) { granted, error in
                AirshipLogger.debug("requestAuthorizationWithOptions \(granted)")

                if let error = error  {
                    AirshipLogger.error("requestAuthorizationWithOptions failed with error: \(error)")
                }
                completionHandler()
            }
        }
    }
}


private extension UNAuthorizationStatus {
    var airshipStatus: UAAuthorizationStatus {
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

        if #available(iOS 14.0, *) {
            if (self == .ephemeral) {
                return .ephemeral;
            }
        }

#endif

        AirshipLogger.warn("Unable to handle UNAuthorizationStatus: \(self.rawValue)")
        return .notDetermined
    }
}


private extension UNNotificationSettings {
    var airshipSettings: UAAuthorizedNotificationSettings {
        var authorizedSettings: UAAuthorizedNotificationSettings = []
#if !os(watchOS)
        if (self.badgeSetting == .enabled) {
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

        if #available(iOS 13.0, *) {
            if self.announcementSetting == .enabled {
                authorizedSettings.insert(.announcement)
            }
        }

#endif


#if !os(tvOS) && !targetEnvironment(macCatalyst)

        if #available(iOS 15.0, *) {
            if self.timeSensitiveSetting == .enabled {
                authorizedSettings.insert(.timeSensitive)
            }

            if self.scheduledDeliverySetting == .enabled {
                authorizedSettings.insert(.scheduledDelivery)
            }
        }

#endif

        return authorizedSettings
    }
}


private extension UANotificationOptions {
    var appleOptions: UNAuthorizationOptions {
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
        if #available(iOS 13.0, *) {
            // Avoids deprecation warning
            let annoucement = UANotificationOptions(rawValue: (1 << 7))
            if self.contains(annoucement) {
                authorizedOptions.insert(.announcement)
            }
        }
#endif

        return authorizedOptions
    }
}


