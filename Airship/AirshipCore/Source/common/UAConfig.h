/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

#import "UAGlobal.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents the possible sites.
 */
typedef NS_ENUM(NSUInteger, UACloudSite) {
    /**
     * Represents the US cloud site. This is the default value.
     * Projects avialable at go.airship.com must use this value.
     */
    UACloudSiteUS = 0,

    /**
     * Represents the EU cloud site.
     * Projects avialable at go.airship.eu must use this value.
     */
    UACloudSiteEU = 1,
};

/**
 * The UAConfig object provides an interface for passing common configurable values to [UAirship takeOff].
 * The simplest way to use this class is to add an AirshipConfig.plist file in your app's bundle and set
 * the desired options. The plist keys use the same names as this class's configuration options. Older,
 * all-caps keys are still supported, but you should migrate your properties file to make use of a number 
 * of new options.
 */
@interface UAConfig : NSObject <NSCopying>

///---------------------------------------------------------------------------------------
/// @name Configuration Options
///---------------------------------------------------------------------------------------

/**
 * The development app key. This should match the application on go.urbanairship.com that is
 * configured with your development push certificate.
 */
@property (nonatomic, copy, nullable) NSString *developmentAppKey;

/**
 * The development app secret. This should match the application on go.urbanairship.com that is
 * configured with your development push certificate.
 */
@property (nonatomic, copy, nullable) NSString *developmentAppSecret;

/**
 * The production app key. This should match the application on go.urbanairship.com that is
 * configured with your production push certificate. This is used for App Store, Ad-Hoc and Enterprise
 * app configurations.
 */
@property (nonatomic, copy, nullable) NSString *productionAppKey;

/**
 * The production app secret. This should match the application on go.urbanairship.com that is
 * configured with your production push certificate. This is used for App Store, Ad-Hoc and Enterprise
 * app configurations.
 */
@property (nonatomic, copy, nullable) NSString *productionAppSecret;

/**
 * The log level used for development apps. Defaults to `UALogLevelDebug` (4).
 */
@property (nonatomic, assign) UALogLevel developmentLogLevel;

/**
 * The log level used for production apps. Defaults to `UALogLevelError` (1).
 */
@property (nonatomic, assign) UALogLevel productionLogLevel;

@property (nonatomic, assign) UACloudSite site;

/**
 * Flag indicating whether data collection needs to be opted in with
 * `UAirship.dataCollectionEnabled`. This flag will only take affect on first run.
 * If previously not enabled, the device will still have data collection enabled until disabled with
 * `UAirship.dataCollectionEnabled`.
*/
@property (nonatomic, assign, getter=isDataCollectionOptInEnabled) BOOL dataCollectionOptInEnabled;

/**
 * The default app key. Depending on the `inProduction` status,
 * `developmentAppKey` or `productionAppKey` will take priority.
 */
@property (nonatomic, copy, nullable) NSString *defaultAppKey;

/**
 * The default app secret. Depending on the `inProduction` status,
 * `developmentAppSecret` or `productionAppSecret` will take priority.
 */
@property (nonatomic, copy, nullable) NSString *defaultAppSecret;


/**
 * The production status of this application. This may be set directly, or it may be determined
 * automatically if the detectProvisioningMode flag is set to `YES`.
 */
@property (nonatomic, assign, getter=isInProduction) BOOL inProduction;

/**
 * If enabled, the Airship library automatically registers for remote notifications when push is enabled
 * and intercepts incoming notifications in both the foreground and upon launch.
 *
 * Defaults to YES. If this is disabled, you will need to register for remote notifications
 * in application:didFinishLaunchingWithOptions: and forward all notification-related app delegate
 * calls to UAPush and UAInbox.
 */
@property (nonatomic, assign, getter=isAutomaticSetupEnabled) BOOL automaticSetupEnabled;

/**
 * An array of UAWhitelist entry strings. The whitelist used for validating URLs for landing pages,
 * wallet action, open external URL action, deep link action (if delegate is not set), and
 * HTML in-app messages.
 *
 * @note See UAWhitelist for pattern entry syntax.
 */
@property (nonatomic, copy) NSArray<NSString *> *whitelist;

/**
 * The iTunes ID used for Rate App Actions.
 */
@property (nonatomic, copy) NSString *itunesID;

///---------------------------------------------------------------------------------------
/// @name Advanced Configuration Options
///---------------------------------------------------------------------------------------

/**
 * Toggles Airship analytics. Defaults to `YES`. If set to `NO`, many Airship features will not be
 * available to this application.
 */
@property (nonatomic, assign, getter=isAnalyticsEnabled) BOOL analyticsEnabled;

/**
 * Apps may be set to self-configure based on the APS-environment set in the
 * embedded.mobileprovision file by using detectProvisioningMode. If
 * detectProvisioningMode is set to `YES`, the inProduction value will
 * be determined at runtime by reading the provisioning profile. If it is set to
 * `NO` (the default), the inProduction flag may be set directly or by using the
 * AirshipConfig.plist file.
 *
 * When this flag is enabled, the inProduction flag defaults to `YES` for safety
 * so that the production keys will always be used if the profile cannot be read
 * in a released app. Simulator builds do not include the profile, and the
 * detectProvisioningMode flag does not have any effect in cases where a profile
 * is not present. When a provisioning file is not present, the app will fall
 * back to the inProduction property as set in code or the AirshipConfig.plist
 * file.
 */
@property (nonatomic, assign) BOOL detectProvisioningMode;

/**
 * The Airship default message center style configuration file.
 */
@property (nonatomic, copy) NSString *messageCenterStyleConfig;

/**
 * If set to `YES`, the Airship user will be cleared if the application is
 * restored on a different device from an encrypted backup.
 *
 * Defaults to `NO`.
 */
@property (nonatomic, assign) BOOL clearUserOnAppRestore;

/**
 * If set to `YES`, the application will clear the previous named user ID on a
 * re-install. Defaults to `NO`.
 */
@property (nonatomic, assign) BOOL clearNamedUserOnAppRestore;

/**
 * Flag indicating whether channel capture feature is enabled or not.
 *
 * Defaults to `YES`.
 */
@property (nonatomic, assign, getter=isChannelCaptureEnabled) BOOL channelCaptureEnabled;

/**
 * Enables or disables whitelist checks at the scope `UAWhitelistScopeOpenURL`. If disabled,
 * all whitelist checks for this scope will be allowed.
 *
 * Defaults to `NO`.
 */
@property (nonatomic, assign, getter=isOpenURLWhitelistingEnabled) BOOL openURLWhitelistingEnabled;

/**
 * Flag indicating whether delayed channel creation is enabled. If set to `YES` channel 
 * creation will not occur until channel creation is manually enabled.
 *
 * Defaults to `NO`.
 */
@property (nonatomic, assign, getter=isChannelCreationDelayEnabled) BOOL channelCreationDelayEnabled;

/**
 * Dictionary of custom config values.
 */
@property (nonatomic, copy) NSDictionary *customConfig;

/**
 * If set to 'YES', the Airship SDK will request authorization to use
 * notifications from the user. Apps that set this flag to `NO` are
 * required to request authorization themselves.
 *
 * Defaults to `YES`.
 */
@property (nonatomic, assign) BOOL requestAuthorizationToUseNotifications;

///---------------------------------------------------------------------------------------
/// @name Internal Configuration Options
///---------------------------------------------------------------------------------------

/**
 * The Airship device API url.
 *
 * @note This option is reserved for internal debugging. :nodoc:
 */
@property (nonatomic, copy) NSString *deviceAPIURL;

/**
 * The Airship analytics API url.
 *
 * @note This option is reserved for internal debugging. :nodoc:
 */
@property (nonatomic, copy) NSString *analyticsURL;

/**
 * The Airship remote data API url.
 *
 * @note This option is reserved for internal debugging. :nodoc:
 */
@property (nonatomic, copy) NSString *remoteDataAPIURL;

///---------------------------------------------------------------------------------------
/// @name Factory Methods
///---------------------------------------------------------------------------------------

/**
 * Creates an instance using the values set in the `AirshipConfig.plist` file.
 * @return A UAConfig with values from `AirshipConfig.plist` file.
 */
+ (UAConfig *)defaultConfig;

/**
 * Creates an instance using the values found in the specified `.plist` file.
 * @param path The path of the specified file.
 * @return A UAConfig with values from the specified file.
 */
+ (UAConfig *)configWithContentsOfFile:(NSString *)path;

/**
 * Creates an instance with empty values.
 * @return A UAConfig with empty values.
 */
+ (UAConfig *)config;

///---------------------------------------------------------------------------------------
/// @name Resolved values
///---------------------------------------------------------------------------------------

/**
 * Returns the resolved app key.
 * @return The resolved app key or an empty string.
 */
@property (readonly, nonnull) NSString *appKey;

/**
 * Returns the resolved app secret.
 * @return The resolved app key or an empty string.
 */
@property (readonly, nonnull) NSString *appSecret;

/**
 * Returns the resolved log level.
 * @return The resolved log level.
 */
 @property (readonly) UALogLevel logLevel;

///---------------------------------------------------------------------------------------
/// @name Utilities, Helpers
///---------------------------------------------------------------------------------------

/**
 * Validates the current configuration. In addition to performing a strict validation, this method
 * will log warnings and common configuration errors.
 * @return `YES` if the current configuration is valid, otherwise `NO`.
 */
- (BOOL)validate;

@end

NS_ASSUME_NONNULL_END
