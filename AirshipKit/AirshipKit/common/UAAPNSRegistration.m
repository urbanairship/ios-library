/* Copyright 2018 Urban Airship and Contributors */

#import "UAAPNSRegistration+Internal.h"
#import "UANotificationCategory.h"

@implementation UAAPNSRegistration

@synthesize registrationDelegate;

-(void)getAuthorizedSettingsWithCompletionHandler:(void (^)(UAAuthorizedNotificationSettings, BOOL))completionHandler NS_AVAILABLE_IOS(10.0) {
    [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull notificationSettings) {

        UNAuthorizationStatus status = notificationSettings.authorizationStatus;
        UAAuthorizedNotificationSettings authorizedSettings = UAAuthorizedNotificationSettingsNone;
        BOOL isProvisional = NO;

        if (@available(iOS 12.0, *)) {
            isProvisional = (status == UNAuthorizationStatusProvisional);
        }

        if (status != UNAuthorizationStatusAuthorized && !isProvisional) {
            completionHandler(authorizedSettings, NO);
            return;
        }

        if (notificationSettings.badgeSetting == UNNotificationSettingEnabled) {
            authorizedSettings |= UAAuthorizedNotificationSettingsBadge;
        }

#if !TARGET_OS_TV
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
#endif
        completionHandler(authorizedSettings, isProvisional);
    }];
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

    // Critical alert and provisional authorization are iOS 12+
    if (@available(iOS 12.0, *)) {
        if ((uaOptions & UANotificationOptionCriticalAlert) == UANotificationOptionCriticalAlert) {
            unOptions |= UNAuthorizationOptionCriticalAlert;
        }

        if ((uaOptions & UANotificationOptionProvisional) == UANotificationOptionProvisional) {
            unOptions |= UNAuthorizationOptionProvisional;
        }
    }

    return unOptions;
}

-(void)updateRegistrationWithOptions:(UANotificationOptions)options
                          categories:(NSSet<UANotificationCategory *> *)categories NS_AVAILABLE_IOS(10.0) {

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
                              [self getAuthorizedSettingsWithCompletionHandler:^(UAAuthorizedNotificationSettings authorizedSettings, BOOL provisional) {
                                  [self.registrationDelegate notificationRegistrationFinishedWithAuthorizedSettings:authorizedSettings provisional:provisional];
                              }];
                          }];
}

@end

