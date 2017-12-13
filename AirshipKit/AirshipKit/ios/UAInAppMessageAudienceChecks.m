/* Copyright 2017 Urban Airship and Contributors */

#import "UAInAppMessageAudienceChecks+Internal.h"
#import "UAInAppMessageAudience+Internal.h"
#import "UAirship+Internal.h"
#import "UALocation+Internal.h"
#import "UAApplicationMetrics+Internal.h"
#import "UAPush+Internal.h"
#import "UAInAppMessageTagSelector.h"
#import "UAVersionMatcher+Internal.h"

@implementation UAInAppMessageAudienceChecks

+ (BOOL)checkAudience:(UAInAppMessageAudience *)audience isNewUser:(BOOL)isNewUser {
    if (!audience) {
        return YES;
    }
    
    if ((audience.isNewUser) && ([audience.isNewUser boolValue] != isNewUser)) {
        return NO;
    }
        
    return [self checkAudience:audience];
    
}
+ (BOOL)checkAudience:(UAInAppMessageAudience *)audience {
    if (!audience) {
        return YES;
    }
    
    // Location opt-in
    if (audience.locationOptIn && ([audience.locationOptIn boolValue] != [UAirship location].locationUpdatesEnabled)) {
        return NO;
    }
    
    // Notification opt-in
    if (audience.notificationsOptIn && ([audience.notificationsOptIn boolValue] != [UAirship push].userPushNotificationsEnabled)) {
        return NO;
    }

    // Tag Selector
    if (audience.tagSelector && ![audience.tagSelector apply:[UAirship push].tags]) {
        return NO;
    }

    // Locales
    if ((audience.languageIDs) && [audience.languageIDs isKindOfClass:[NSArray class]]) {
        NSLocale *currentLocale = [NSLocale currentLocale];
        for (NSString *audienceLanguageID in audience.languageIDs) {
            NSLocale *audienceLocale = [NSLocale localeWithLocaleIdentifier:audienceLanguageID];

            // check language code
            NSString *currentLanguageCode;
            NSString *audienceLanguageCode;
            if (@available(iOS 10.0, tvOS 10.0, *)) {
                currentLanguageCode = currentLocale.languageCode;
                audienceLanguageCode = audienceLocale.languageCode;
            } else {
                NSDictionary *currentComponents = [NSLocale componentsFromLocaleIdentifier:currentLocale.localeIdentifier];
                currentLanguageCode = currentComponents[NSLocaleLanguageCode];
                NSDictionary *audienceComponents = [NSLocale componentsFromLocaleIdentifier:audienceLocale.localeIdentifier];
                audienceLanguageCode = audienceComponents[NSLocaleLanguageCode];
            }
            if (![currentLanguageCode isEqualToString:audienceLanguageCode]) {
                continue;
            }
            NSString *currentCountryCode;
            NSString *audienceCountryCode;
            if (@available(iOS 10.0, tvOS 10.0, *)) {
                currentCountryCode = currentLocale.countryCode;
                audienceCountryCode = audienceLocale.countryCode;
            } else {
                NSDictionary *currentComponents = [NSLocale componentsFromLocaleIdentifier:currentLocale.localeIdentifier];
                currentCountryCode = currentComponents[NSLocaleCountryCode];
                NSDictionary *audienceComponents = [NSLocale componentsFromLocaleIdentifier:audienceLocale.localeIdentifier];
                audienceCountryCode = audienceComponents[NSLocaleCountryCode];
            }
            if (audienceCountryCode && ![currentCountryCode isEqualToString:audienceCountryCode]) {
                continue;
            }
            return YES;
        }
        return NO;
    }
    
    // version
    if (audience.versionMatcher) {
        NSString *currentAppVersion = [UAirship shared].applicationMetrics.currentAppVersion;
        if (![audience.versionMatcher evaluateObject:currentAppVersion]) {
            return NO;
        }
    }
    
    return YES;
}

@end
