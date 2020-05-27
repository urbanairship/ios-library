/* Copyright Airship and Contributors */

#import <CommonCrypto/CommonDigest.h>

#import "UAInAppMessageAudienceChecks+Internal.h"
#import "UAInAppMessageAudience+Internal.h"
#import "UAInAppMessageTagSelector+Internal.h"
#import "UAAirshipAutomationCoreImport.h"

@implementation UAInAppMessageAudienceChecks

+ (BOOL)checkScheduleAudienceConditions:(UAInAppMessageAudience *)audience isNewUser:(BOOL)isNewUser {
    if (!audience) {
        return YES;
    }
    
    if ((audience.isNewUser) && ([audience.isNewUser boolValue] != isNewUser)) {
        return NO;
    }

    if (audience.testDevices.count) {
        NSString *channel = [UAirship channel].identifier;
        if (!channel) {
            return NO;
        }

        NSData *digest = [[UAUtils sha256DigestWithString:channel] subdataWithRange:NSMakeRange(0, 16)];
        for (NSString *testDevice in audience.testDevices) {
            NSData *decoded = UA_dataFromBase64String(testDevice);
            if ([decoded isEqual:digest]) {
                return YES;
            }
        }

        return NO;
    }

    return YES;
}

+ (BOOL)checkDisplayAudienceConditions:(UAInAppMessageAudience *)audience tagGroups:(UATagGroups *)tagGroups {
    if (!audience) {
        return YES;
    }

    // Data collection enabled
    BOOL isDataCollectionEnabled = [UAirship shared].isDataCollectionEnabled;
    
    // Location opt-in
    if (audience.locationOptIn) {
        if (!isDataCollectionEnabled) {
            return NO;
        }

        if ([audience.locationOptIn boolValue] != [UAirship shared].locationProvider.isLocationOptedIn) {
            return NO;
        }
    }

    // Notification opt-in
    if (audience.notificationsOptIn) {
        if (!isDataCollectionEnabled) {
            return NO;
        }

        if ([audience.notificationsOptIn boolValue] != [self isNotificationsOptedIn]) {
            return NO;
        }
    }

    // Tag Selector
    if (audience.tagSelector) {
        if (!isDataCollectionEnabled) {
            return NO;
        }

        if (![audience.tagSelector apply:[UAirship channel].tags tagGroups:tagGroups]) {
            return NO;
        }
    }

    // Locales
    if (![self areLocationConditionsMet:audience]) {
        return NO;
    }


    // Version
    if (audience.versionPredicate) {
        NSString *currentVersion = [UAirship shared].applicationMetrics.currentAppVersion;
        id versionObject = currentVersion ? @{@"ios" : @{@"version": currentVersion}} : nil;
        if (!versionObject || ![audience.versionPredicate evaluateObject:versionObject]) {
            return NO;
        }
    }

    return YES;
}

+ (BOOL)areLocationConditionsMet:(UAInAppMessageAudience *)audience {
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

+ (BOOL)checkDisplayAudienceConditions:(UAInAppMessageAudience *)audience {
    return [self checkDisplayAudienceConditions:audience tagGroups:[UATagGroups tagGroupsWithTags:@{}]];
}


+ (BOOL)isNotificationsOptedIn {
    return [UAirship push].userPushNotificationsEnabled && [UAirship push].authorizedNotificationSettings != UAAuthorizedNotificationSettingsNone;
}

@end
