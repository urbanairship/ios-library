/* Copyright 2018 Urban Airship and Contributors */

#import "UAAPNSRegistration+Internal.h"
#import "UANotificationCategory.h"

@implementation UAAPNSRegistration

@synthesize registrationDelegate;

-(void)getAuthorizedSettingsWithCompletionHandler:(void (^)(UAAuthorizedNotificationSettings))completionHandler NS_AVAILABLE_IOS(10.0) {
    [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull notificationSettings) {

        UAAuthorizedNotificationSettings authorizedSettings = UAAuthorizedNotificationSettingsNone;

        if (notificationSettings.authorizationStatus != UNAuthorizationStatusAuthorized) {
            completionHandler(authorizedSettings);
            return;
        }


        if (notificationSettings.authorizationStatus == UNAuthorizationStatusAuthorized) {

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
            completionHandler(authorizedSettings);
        }}];
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

    UNAuthorizationOptions normalizedOptions = (UNAuthorizationOptionAlert | UNAuthorizationOptionBadge | UNAuthorizationOptionSound | UNAuthorizationOptionCarPlay);
    normalizedOptions &= options;

    [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:normalizedOptions
                                                                        completionHandler:^(BOOL granted, NSError * _Nullable error) {
                                                                            [self getAuthorizedSettingsWithCompletionHandler:^(UAAuthorizedNotificationSettings authorizedSettings) {
                                                                                [self.registrationDelegate notificationRegistrationFinishedWithAuthorizedSettings:authorizedSettings];
                                                                            }];
                                                                        }];
}

@end

