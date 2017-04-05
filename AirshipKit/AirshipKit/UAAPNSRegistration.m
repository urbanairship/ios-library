/* Copyright 2017 Urban Airship and Contributors */

#import "UAAPNSRegistration+Internal.h"
#import "UANotificationCategory+Internal.h"

@implementation UAAPNSRegistration

-(void)getCurrentAuthorizationOptionsWithCompletionHandler:(void (^)(UANotificationOptions))completionHandler {
    [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {

        UANotificationOptions mask = UANotificationOptionNone;

        if (settings.authorizationStatus == UNAuthorizationStatusAuthorized) {
            if (settings.alertSetting == UNNotificationSettingEnabled) {
                mask |= UANotificationOptionAlert;
            }

            if (settings.soundSetting == UNNotificationSettingEnabled) {
                mask |= UANotificationOptionSound;
            }

            if (settings.badgeSetting == UNNotificationSettingEnabled) {
                mask |= UANotificationOptionBadge;
            }

            if (settings.carPlaySetting == UNNotificationSettingEnabled) {
                mask |= UANotificationOptionCarPlay;
            }
        }

        completionHandler(mask);
    }];
}

-(void)updateRegistrationWithOptions:(UANotificationOptions)options
                          categories:(NSSet<UANotificationCategory *> *)categories
                   completionHandler:(void (^)())completionHandler {

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

    UNAuthorizationOptions normalizedOptions = (UNAuthorizationOptionAlert | UNAuthorizationOptionBadge | UNAuthorizationOptionSound | UNAuthorizationOptionCarPlay);
    normalizedOptions &= options;


    if (normalizedOptions != UNAuthorizationOptionNone) {
        [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:normalizedOptions
                                                                            completionHandler:^(BOOL granted, NSError * _Nullable error) {
                                                                                UA_LDEBUG(@"Registering for user notification options %ld.", (unsigned long)[UAirship push].notificationOptions);

                                                                                [[UIApplication sharedApplication] registerForRemoteNotifications];
                                                                                completionHandler();
                                                                            }];
    } else {
        [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
            if (settings.authorizationStatus == UNAuthorizationStatusNotDetermined) {
                // Return early so we dont trigger the user to accept notifications
                completionHandler();
                return;
            }

            [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:UNAuthorizationOptionNone
                                                                                completionHandler:^(BOOL granted, NSError * _Nullable error) {
                                                                                    UA_LDEBUG(@"Unregistered for user notification options");
                                                                                    completionHandler();
                                                                                }];
        }];
    }
}

@end

