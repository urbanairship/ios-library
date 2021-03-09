/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Model object for state overrides data.
 */
@interface UAStateOverrides : NSObject

/**
 * The app version.
 */
@property (nonatomic, readonly) NSString *appVersion;

/**
 * The SDK version.
 */
@property (nonatomic, readonly) NSString *sdkVersion;

/**
 * The locale language.
 */
@property (nonatomic, readonly) NSString *localeLanguage;

/**
 * The locale country.
 */
@property (nonatomic, readonly, nullable) NSString *localeCountry;

/**
 * Whether notifications are opted in.
 */
@property (nonatomic, readonly) BOOL notificationOptIn;

/**
 * UAStateOverrides factory method.
 *
 * @param appVersion The app version.
 * @param sdkVersion The SDK version.
 * @param localeLanguage The locale language.
 * @param localeCountry The locale country.
 * @param notificationOptIn Whether notifications are opted in.
 */
+ (instancetype)stateOverridesWithAppVersion:(NSString *)appVersion
                                  sdkVersion:(NSString *)sdkVersion
                              localeLanguage:(NSString *)localeLanguage
                               localeCountry:(nullable NSString *)localeCountry
                           notificationOptIn:(BOOL)notificationOptIn;

/**
 * UAStateOverrides factory method, with default values.
 */
+ (instancetype)defaultStateOverrides;

@end

NS_ASSUME_NONNULL_END
