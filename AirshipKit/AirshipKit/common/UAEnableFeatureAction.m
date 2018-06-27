/* Copyright 2018 Urban Airship and Contributors */

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
    [[UAirship push].pushRegistration getAuthorizedSettingsWithCompletionHandler:^(UAAuthorizedNotificationSettings authorizedSettings) {
        callback(authorizedSettings != UAAuthorizedNotificationSettingsNone);
    }];
}

- (BOOL)isLocationDeniedOrRestricted {
    switch ([CLLocationManager authorizationStatus]) {
        case kCLAuthorizationStatusDenied:
        case kCLAuthorizationStatusRestricted:
            return YES;
        case kCLAuthorizationStatusNotDetermined:
        case kCLAuthorizationStatusAuthorizedAlways:
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            return NO;
    }
}

- (void)navigateToSystemSettings {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
#pragma GCC diagnostic pop
}

- (void)enableUserNotifications:(UAActionCompletionHandler)completionHandler {
    [UAirship push].userPushNotificationsEnabled = YES;
    if ([UAirship push].userPromptedForNotifications) {
        [self isNotificationsAuthorized:^(BOOL authorized) {
            if (!authorized) {
                [self navigateToSystemSettings];
                completionHandler([UAActionResult emptyResult]);
            }
        }];
    } else {
        completionHandler([UAActionResult emptyResult]);
    }
}

- (void)enableBackgroundLocation:(UAActionCompletionHandler)completionHandler {
    [UAirship location].locationUpdatesEnabled = YES;
    [UAirship location].backgroundLocationUpdatesAllowed = YES;

    if ([self isLocationDeniedOrRestricted]) {
        [self navigateToSystemSettings];
    }

    completionHandler([UAActionResult emptyResult]);
}

- (void)enableLocation:(UAActionCompletionHandler)completionHandler {
    [UAirship location].locationUpdatesEnabled = YES;
    if ([self isLocationDeniedOrRestricted]) {
        [self navigateToSystemSettings];
    }

    completionHandler([UAActionResult emptyResult]);
}

@end
