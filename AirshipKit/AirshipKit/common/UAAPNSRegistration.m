/* Copyright Urban Airship and Contributors */

#import "UAAPNSRegistration+Internal.h"
#import "UANotificationCategory.h"

@implementation UAAPNSRegistration

@synthesize registrationDelegate;

-(void)getAuthorizedSettingsWithCompletionHandler:(void (^)(UAAuthorizedNotificationSettings, UAAuthorizationStatus))completionHandler {
    [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull notificationSettings) {

        UAAuthorizationStatus authorizationStatus = [self uaStatus:notificationSettings.authorizationStatus];
        UAAuthorizedNotificationSettings authorizedSettings = UAAuthorizedNotificationSettingsNone;

        if (notificationSettings.badgeSetting == UNNotificationSettingEnabled) {
            authorizedSettings |= UAAuthorizedNotificationSettingsBadge;
        }

#if !TARGET_OS_TV // Only badge settings are available on tvOS
        if (notificationSettings.soundSetting == UNNotificationSettingEnabled) {
            authorizedSettings |= UAAuthorizedNotificationSettingsSound;
        }

        if (notificationSettings.alertSetting == UNNotificationSettingEnabled) {
            authorizedSettings |= UAAuthorizedNotificationSettingsAlert;
        }

        if (notificationSettings.carPlaySetting == UNNotificationSettingEnabled) {
            authorizedSettings |= UAAuthorizedNotificationSettingsCarPlay;
        }

        if (notificationSettings.lockScreenSetting == UNNotificationSettingEnabled) {
            authorizedSettings |= UAAuthorizedNotificationSettingsLockScreen;
        }

        if (notificationSettings.notificationCenterSetting == UNNotificationSettingEnabled) {
            authorizedSettings |= UAAuthorizedNotificationSettingsNotificationCenter;
        }
        
        if (@available(iOS 12.0, *)) {
            if (notificationSettings.criticalAlertSetting == UNNotificationSettingEnabled) {
                authorizedSettings |= UAAuthorizedNotificationSettingsCriticalAlert;
            }
        }
#endif

        completionHandler(authorizedSettings, authorizationStatus);
    }];
}

- (UAAuthorizationStatus)uaStatus:(UNAuthorizationStatus)status {
    if (@available(iOS 12.0, tvOS 12.0, *)) {
        if (status == UNAuthorizationStatusProvisional) {
            return UAAuthorizationStatusProvisional;
        }
    }

    if (status == UNAuthorizationStatusNotDetermined) {
        return UAAuthorizationStatusNotDetermined;
    } else if (status == UNAuthorizationStatusDenied) {
        return UAAuthorizationStatusDenied;
    } else if (status == UNAuthorizationStatusAuthorized) {
        return UAAuthorizationStatusAuthorized;
    }

    UA_LWARN(@"Unable to handle UNAuthorizationStatus: %ld", (long)status);
    return UAAuthorizationStatusNotDetermined;
}

- (UNAuthorizationOptions)normalizedOptions:(UANotificationOptions)uaOptions {
    UNAuthorizationOptions unOptions = UNAuthorizationOptionNone;

    if ((uaOptions & UANotificationOptionBadge) == UANotificationOptionBadge) {
        unOptions |= UNAuthorizationOptionBadge;
    }

    if ((uaOptions & UANotificationOptionSound) == UANotificationOptionSound) {
        unOptions |= UNAuthorizationOptionSound;
    }

    if ((uaOptions & UANotificationOptionAlert) == UANotificationOptionAlert) {
        unOptions |= UNAuthorizationOptionAlert;
    }

    if ((uaOptions & UANotificationOptionCarPlay) == UANotificationOptionCarPlay) {
        unOptions |= UNAuthorizationOptionCarPlay;
    }

    // These authorization options and settings are iOS 12+
    if (@available(iOS 12.0, tvOS 12.0, *)) {
        if ((uaOptions & UANotificationOptionCriticalAlert) == UANotificationOptionCriticalAlert) {
            unOptions |= UNAuthorizationOptionCriticalAlert;
        }

        if ((uaOptions & UANotificationOptionProvidesAppNotificationSettings) == UANotificationOptionProvidesAppNotificationSettings) {
            unOptions |= UNAuthorizationOptionProvidesAppNotificationSettings;
        }

        if ((uaOptions & UANotificationOptionProvisional) == UANotificationOptionProvisional) {
            unOptions |= UNAuthorizationOptionProvisional;
        }
    }

    return unOptions;
}

-(void)updateRegistrationWithOptions:(UANotificationOptions)options
                          categories:(NSSet<UANotificationCategory *> *)categories
                   completionHandler:(nullable void(^)(BOOL success))completionHandler {

#if !TARGET_OS_TV   // UNNotificationCategory not supported on tvOS
    NSMutableSet *normalizedCategories;

    if (categories) {
        normalizedCategories = [NSMutableSet set];

        // Normalize our abstract categories to iOS-appropriate type
        for (UANotificationCategory *category in categories) {

            id normalizedCategory = [category asUNNotificationCategory];

            // iOS 10 beta this could return nil
            if (normalizedCategory) {
                [normalizedCategories addObject:normalizedCategory];
            }
        }
    }

    [[UNUserNotificationCenter currentNotificationCenter] setNotificationCategories:[NSSet setWithSet:normalizedCategories]];
#endif

    UNAuthorizationOptions normalizedOptions = [self normalizedOptions:options];

    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];

    [center requestAuthorizationWithOptions:normalizedOptions
                          completionHandler:^(BOOL granted, NSError * _Nullable error) {
                              if (error) {
                                  UA_LERR(@"requestAuthorizationWithOptions failed with error: %@", error);
                              }

                              if (completionHandler) {
                                  completionHandler(granted);
                              }

                              [self getAuthorizedSettingsWithCompletionHandler:^(UAAuthorizedNotificationSettings authorizedSettings, UAAuthorizationStatus status) {
                                  [self.registrationDelegate notificationRegistrationFinishedWithAuthorizedSettings:authorizedSettings status:status];
                              }];
                          }];
}

@end

