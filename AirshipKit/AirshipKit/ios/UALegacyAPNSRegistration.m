/* Copyright 2018 Urban Airship and Contributors */

#import "UALegacyAPNSRegistration+Internal.h"
#import "UANotificationCategory.h"

@implementation UALegacyAPNSRegistration

@synthesize registrationDelegate;

- (UAAuthorizedNotificationSettings)authorizedSettingsForLegacySettings:(UIUserNotificationSettings *)legacySettings {
    UAAuthorizedNotificationSettings authorizedSettings = UAAuthorizedNotificationSettingsNone;

    UIUserNotificationType types = legacySettings.types;

    if (types & UIUserNotificationTypeBadge) {
        authorizedSettings |= UAAuthorizedNotificationSettingsBadge;
    }

    if (types & UIUserNotificationTypeSound) {
        authorizedSettings |= UAAuthorizedNotificationSettingsSound;
    }

    if (types & UIUserNotificationTypeAlert) {
        authorizedSettings |= UAAuthorizedNotificationSettingsAlert;
        authorizedSettings |= UAAuthorizedNotificationSettingsLockScreen;
        authorizedSettings |= UAAuthorizedNotificationSettingsNotificationCenter;
    }

    return authorizedSettings;
}

- (void)getAuthorizedSettingsWithCompletionHandler:(void (^)(UAAuthorizedNotificationSettings))completionHandler {
    UIUserNotificationSettings *settings = [[UIApplication sharedApplication] currentUserNotificationSettings];
    completionHandler([self authorizedSettingsForLegacySettings:settings]);
}

-(void)updateRegistrationWithOptions:(UANotificationOptions)options
                          categories:(NSSet<UANotificationCategory *> *)categories {

    NSMutableSet *normalizedCategories;

    if (categories) {
        normalizedCategories = [NSMutableSet set];
        // Normalize our abstract categories to iOS-appropriate type
        for (UANotificationCategory *category in categories) {
            [normalizedCategories addObject:[category asUIUserNotificationCategory]];
        }
    }

    // Only allow alert, badge, and sound
    NSUInteger filteredOptions = options & (UANotificationOptionAlert | UANotificationOptionBadge | UANotificationOptionSound);
    [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:filteredOptions
                                                                                                          categories:normalizedCategories]];
}

- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {
    UAAuthorizedNotificationSettings authorizedSettings = [self authorizedSettingsForLegacySettings:notificationSettings];
    [self.registrationDelegate notificationRegistrationFinishedWithAuthorizedSettings:authorizedSettings];
}

@end
