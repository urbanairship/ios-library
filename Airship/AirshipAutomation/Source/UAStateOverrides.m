/* Copyright Airship and Contributors */

#import "UAStateOverrides+Internal.h"
#import "UAAirshipAutomationCoreImport.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif
@interface UAStateOverrides ()
@property (nonatomic, copy) NSString *appVersion;
@property (nonatomic, copy) NSString *sdkVersion;
@property (nonatomic, copy) NSString *localeLanguage;
@property (nonatomic, copy, nullable) NSString *localeCountry;
@property (nonatomic, assign) BOOL notificationOptIn;
@end

@implementation UAStateOverrides

+ (instancetype)stateOverridesWithAppVersion:(NSString *)appVersion
                                  sdkVersion:(NSString *)sdkVersion
                              localeLanguage:(NSString *)localeLanguage
                               localeCountry:(nullable NSString *)localeCountry
                           notificationOptIn:(BOOL)notificationOptIn {

    UAStateOverrides *overrides = [[super alloc] init];

    overrides.appVersion = appVersion;
    overrides.sdkVersion = sdkVersion;
    overrides.localeLanguage = localeLanguage;
    overrides.localeCountry = localeCountry;
    overrides.notificationOptIn = notificationOptIn;

    return overrides;
}

+ (instancetype)defaultStateOverrides {
    BOOL optIn = [UAirship push].userPushNotificationsEnabled && [UAirship push].authorizedNotificationSettings != UAAuthorizedNotificationSettingsNone;
    
    return [UAStateOverrides stateOverridesWithAppVersion:[UAUtils bundleShortVersionString]
                                               sdkVersion:[UAirshipVersion get]
                                           localeLanguage:[UAirship shared].localeManager.currentLocale.languageCode
                                            localeCountry:[UAirship shared].localeManager.currentLocale.countryCode
                                        notificationOptIn:optIn];
}

@end
