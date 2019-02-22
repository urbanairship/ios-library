/* Copyright Urban Airship and Contributors */

#import "UAEnableFeatureAction.h"
#import "UAirship.h"
#import "UALocation.h"
#import "UAPush+Internal.h"


NSString *const UAEnableUserNotificationsActionValue = @"user_notifications";
NSString *const UAEnableLocationActionValue = @"location";
NSString *const UAEnableBackgroundLocationActionValue = @"background_location";

@implementation UAEnableFeatureAction


- (BOOL)acceptsArguments:(UAActionArguments *)arguments {

    if (arguments.situation == UASituationBackgroundPush || arguments.situation == UASituationBackgroundInteractiveButton) {
        return NO;
    }

    if (![arguments.value isKindOfClass:[NSString class]]) {
        return NO;
    }

    NSString *value = arguments.value;
    if ([value isEqualToString:UAEnableUserNotificationsActionValue] || [value isEqualToString:UAEnableLocationActionValue] || [value isEqualToString:UAEnableBackgroundLocationActionValue]) {
        return YES;
    }

    return NO;
}

- (void)performWithArguments:(UAActionArguments *)arguments
           completionHandler:(UAActionCompletionHandler)completionHandler {
    if ([arguments.value isEqualToString:UAEnableUserNotificationsActionValue]) {
        [self enableUserNotifications:completionHandler];
    } else if ([arguments.value isEqualToString:UAEnableBackgroundLocationActionValue]) {
        [self enableBackgroundLocation:completionHandler];
    } else if ([arguments.value isEqualToString:UAEnableLocationActionValue]) {
        [self enableLocation:completionHandler];
    } else {
        completionHandler([UAActionResult emptyResult]);
    }
}

- (void)isNotificationsAuthorized:(void (^)(BOOL))callback {
    [[UAirship push].pushRegistration getAuthorizedSettingsWithCompletionHandler:^(UAAuthorizedNotificationSettings authorizedSettings, UAAuthorizationStatus status) {
        callback(authorizedSettings != UAAuthorizedNotificationSettingsNone);
    }];
}

- (BOOL)isLocationDeniedOrRestricted {
    return UAirship.location.isLocationDeniedOrRestricted;
}

- (void)navigateToSystemSettingsWithCompletionHandler:(UAActionCompletionHandler)completionHandler {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]
                                       options:@{}
                             completionHandler:^(BOOL success) {
                                 completionHandler([UAActionResult emptyResult]);
                             }];
}

- (void)enableUserNotifications:(UAActionCompletionHandler)completionHandler {
    [UAirship push].userPushNotificationsEnabled = YES;
    if ([UAirship push].userPromptedForNotifications) {
        [self isNotificationsAuthorized:^(BOOL authorized) {
            if (!authorized) {
                [self navigateToSystemSettingsWithCompletionHandler:completionHandler];
            }
        }];
    } else {
        completionHandler([UAActionResult emptyResult]);
    }
}

- (void)enableBackgroundLocation:(UAActionCompletionHandler)completionHandler {
    UAirship.location.locationUpdatesEnabled = YES;
    UAirship.location.backgroundLocationUpdatesAllowed = YES;

    if ([self isLocationDeniedOrRestricted]) {
        [self navigateToSystemSettingsWithCompletionHandler:completionHandler];
    } else {
        completionHandler([UAActionResult emptyResult]);
    }
}

- (void)enableLocation:(UAActionCompletionHandler)completionHandler {
    UAirship.location.locationUpdatesEnabled = YES;
    if ([self isLocationDeniedOrRestricted]) {
        [self navigateToSystemSettingsWithCompletionHandler:completionHandler];
    } else {
        completionHandler([UAActionResult emptyResult]);
    }
}

@end
