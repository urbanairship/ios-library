/* Copyright Airship and Contributors */

#import "UAStateOverrides+Internal.h"

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

@end
