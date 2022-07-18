/* Copyright Airship and Contributors */

#import <CommonCrypto/CommonDigest.h>

#import "UAScheduleAudienceChecks+Internal.h"
#import "UAScheduleAudience+Internal.h"
#import "UATagSelector+Internal.h"
#import "UAAirshipAutomationCoreImport.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif
@implementation UAScheduleAudienceChecks

+ (BOOL)checkScheduleAudienceConditions:(UAScheduleAudience *)audience isNewUser:(BOOL)isNewUser {
    if (!audience) {
        return YES;
    }

    if ((audience.isNewUser) && ([audience.isNewUser boolValue] != isNewUser)) {
        return NO;
    }

    if (![self checkTestDeviceCondition:audience]) {
        return NO;
    }

    return YES;
}

+ (BOOL)areLocationConditionsMet:(UAScheduleAudience *)audience {
    if (!audience.languageIDs.count) {
        return YES;
    }

    NSLocale *currentLocale = [NSLocale currentLocale];

    for (NSString *audienceLanguageID in audience.languageIDs) {
        NSLocale *audienceLocale = [NSLocale localeWithLocaleIdentifier:audienceLanguageID];

        // Language
        if (![currentLocale.languageCode isEqualToString:audienceLocale.languageCode]) {
            continue;
        }

        // Country
        if (audienceLocale.countryCode && ![audienceLocale.countryCode isEqualToString:currentLocale.countryCode]) {
            continue;
        }

        return YES;
    }

    return NO;
}

+ (void)checkDisplayAudienceConditions:(UAScheduleAudience *)audience completionHandler:(void (^)(BOOL))completionHandler {
    if (!audience) {
        completionHandler(YES);
        return;
    }

    /// Test devices
    if (![self checkTestDeviceCondition:audience]) {
        completionHandler(NO);
        return;
    }

    /// Notification opt-in
    if (audience.notificationsOptIn) {
        if ([audience.notificationsOptIn boolValue] != [self isNotificationsOptedIn]) {
            completionHandler(NO);
            return;
        }
    }

    /// Tag Selector
    if (audience.tagSelector) {
        if (![[UAirship shared].privacyManager isEnabled:UAFeaturesTagsAndAttributes]) {
            completionHandler(NO);
            return;
        }

        if (![audience.tagSelector apply:[UAirship channel].tags]) {
            completionHandler(NO);
            return;
        }
    }

    /// Locales
    if (![self areLocationConditionsMet:audience]) {
        completionHandler(NO);
        return;
    }


    /// Version
    if (audience.versionPredicate) {
        NSString *currentVersion = [UAirship shared].applicationMetrics.currentAppVersion;
        id versionObject = currentVersion ? @{@"ios" : @{@"version": currentVersion}} : nil;
        if (!versionObject || ![audience.versionPredicate evaluateObject:versionObject]) {
            completionHandler(NO);
            return;
        }
    }
    
    /// Requires analytics
    if ([audience.requiresAnalytics boolValue]) {
        if (![[UAirship shared].privacyManager isEnabled:UAFeaturesAnalytics]) {
            completionHandler(NO);
            return;
        }
    }


    /// Permissions
    if (audience.permissionPredicate || audience.locationOptIn) {
        [UAirship.shared.permissionsManager permissionStatusMapWithCompletionHandler:^(NSDictionary<NSString *,NSString *> * _Nonnull map) {

            if (audience.permissionPredicate && ![audience.permissionPredicate evaluateObject:map]) {
                completionHandler(NO);
                return;
            }

            if (audience.locationOptIn) {
                NSString *locationPermission = map[@"location"];
                if (!locationPermission) {
                    completionHandler(NO);
                    return;
                }

                BOOL granted = [locationPermission isEqualToString:@"granted"];
                completionHandler(granted == [audience.locationOptIn boolValue]);
            }
        }];
    } else {
        completionHandler(YES);
    }
}


+ (BOOL)isNotificationsOptedIn {
    return [UAirship push].userPushNotificationsEnabled && [UAirship push].authorizedNotificationSettings != UAAuthorizedNotificationSettingsNone;
}

+ (BOOL)checkTestDeviceCondition:(UAScheduleAudience *)audience {
    if (audience.testDevices.count) {
        NSString *channel = [UAirship channel].identifier;
        if (!channel) {
            return NO;
        }

        NSData *digest = [[UAUtils sha256DigestWithString:channel] subdataWithRange:NSMakeRange(0, 16)];
        for (NSString *testDevice in audience.testDevices) {
            NSData *decoded = [UABase64 dataFromString:testDevice];
            if ([decoded isEqual:digest]) {
                return YES;
            }
        }

        return NO;
    }

    return YES;
}

@end
