/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

#import "UAGlobal.h"
#import "UAPrivacyManager.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Airship config needed for runtime. Generated from `UAConfig` during takeOff.
 */
@interface UARuntimeConfig : NSObject

///---------------------------------------------------------------------------------------
/// @name Configuration Options
///---------------------------------------------------------------------------------------

/**
 * If enabled, the Airship library automatically registers for remote notifications when push is enabled
 * and intercepts incoming notifications in both the foreground and upon launch.
 *
 * Defaults to YES. If this is disabled, you will need to register for remote notifications
 * in application:didFinishLaunchingWithOptions: and forward all notification-related app delegate
 * calls to UAPush and UAInbox.
 */
@property (readonly, getter=isAutomaticSetupEnabled) BOOL automaticSetupEnabled;

/**
 * An array of UAURLAllowList entry strings.
 * This url allow list is used for validating which URLs can be opened or load the JavaScript native bridge.
 * It affects landing pages, the open external URL and wallet actions,
 * deep link actions (if a delegate is not set), and HTML in-app messages.
 *
 * @note See UAURLAllowList for pattern entry syntax.
 */
@property (readonly) NSArray<NSString *> *URLAllowList;

/**
 * An array of UAURLAllowList entry strings.
 * This url allow list is used for validating which URLs can load the JavaScript native bridge.
 * It affects Landing Pages, Message Center and HTML In-App Messages.
 *
 * @note See UAURLAllowList for pattern entry syntax.
 */
@property (readonly) NSArray<NSString *> *URLAllowListScopeJavaScriptInterface;

/**
 * An array of UAURLAllowList entry strings.
 * This url allow list is used for validating which URLs can be opened.
 * It affects landing pages, the open external URL and wallet actions,
 * deep link actions (if a delegate is not set), and HTML in-app messages.
 *
 * @note See UAURLAllowList for pattern entry syntax.
 */
@property (readonly) NSArray<NSString *> *URLAllowListScopeOpenURL;

/**
 * Whether to suppress console error messages about missing allow list entries during takeOff.
 *
 * Defaults to `NO`.
 */
@property (readonly) BOOL suppressAllowListError;

///---------------------------------------------------------------------------------------
/// @name Advanced Configuration Options
///---------------------------------------------------------------------------------------

/**
 * Toggles Airship analytics. Defaults to `YES`. If set to `NO`, many Airship features will not be
 * available to this application.
 */
@property (readonly, getter=isAnalyticsEnabled) BOOL analyticsEnabled;

/**
 * The Airship device API url.
 *
 * @note This option is reserved for internal debugging. :nodoc:
 */
@property (readonly, nullable) NSString *deviceAPIURL;

/**
 * The Airship analytics API url.
 *
 * @note This option is reserved for internal debugging. :nodoc:
 */
@property (readonly, nullable) NSString *analyticsURL;

/**
 * The Airship remote data url.
 *
 * @note This option is reserved for internal debugging. :nodoc:
 */
@property (readonly, nullable) NSString *remoteDataAPIURL;

/**
 * The Airship chat API URL.
 *
 * @note This option is reserved for internal debugging. :nodoc:
 */
@property (readonly, nullable) NSString *chatURL;

/**
 * The Airship web socket URL.
 *
 * @note This option is reserved for internal debugging. :nodoc:
 */
@property (readonly, nullable) NSString *chatWebSocketURL;

/**
 * The Airship default message center style configuration file.
 */
@property (readonly) NSString *messageCenterStyleConfig;

/**
 * The iTunes ID used for Rate App Actions.
 */
@property (readonly) NSString *itunesID;

/**
 * If set to `YES`, the Airship user will be cleared if the application is
 * restored on a different device from an encrypted backup.
 *
 * Defaults to `NO`.
 */
@property (readonly) BOOL clearUserOnAppRestore;

/**
 * If set to `YES`, the application will clear the previous named user ID on a
 * re-install. Defaults to `NO`.
 */
@property (readonly) BOOL clearNamedUserOnAppRestore;

/**
 * Flag indicating whether channel capture feature is enabled or not.
 *
 * Defaults to `NO`.
 */
@property (readonly, getter=isChannelCaptureEnabled) BOOL channelCaptureEnabled;

/**
 * Flag indicating whether delayed channel creation is enabled. If set to `YES` channel
 * creation will not occur until channel creation is manually enabled.
 *
 * Defaults to `NO`.
 */
@property (readonly, getter=isChannelCreationDelayEnabled) BOOL channelCreationDelayEnabled;

/**
 * Flag indicating whether extended broadcasts are enabled. If set to `YES` the AirshipReady NSNotification
 * will contain additional data: the channel identifier and the app key.
 *
 * Defaults to `NO`.
 */
@property (readonly, getter=isExtendedBroadcastsEnabled) BOOL extendedBroadcastsEnabled;

/**
 * If set to 'YES', the Airship SDK will request authorization to use
 * notifications from the user. Apps that set this flag to `NO` are
 * required to request authorization themselves.
 *
 * Defaults to `YES`.
 */
@property (readonly) BOOL requestAuthorizationToUseNotifications;

/**
 * If set to `YES`, the SDK will wait for an initial remote config instead of falling back on default API URLs.
 *
 * Defaults to `NO`.
 */
@property (readonly) BOOL requireInitialRemoteConfigEnabled;

/**
 * Flag indicating whether data collection needs to be opted in with
 * `UAirship.dataCollectionEnabled`. This flag will only take affect on first run.
 * If previously not enabled, the device will still have data collection enabled until disabled with
 * `UAirship.dataCollectionEnabled`.
 */
@property (readonly, getter=isDataCollectionOptInEnabled) BOOL dataCollectionOptInEnabled;

/**
 * Default enabled Airship features for the app. For more details, see PrivacyManager.
 * Defaults to UAFeaturesAll.
 */
@property (readonly) UAFeatures enabledFeatures;

///---------------------------------------------------------------------------------------
/// @name Resolved Options
///---------------------------------------------------------------------------------------

/**
 * The current app key (resolved using the inProduction flag).
 */
@property (readonly, nonnull) NSString *appKey;

/**
 * The current app secret (resolved using the inProduction flag).
 */
@property (readonly, nonnull) NSString *appSecret;

/**
 * The current log level for the library's UA_L<level> macros (resolved using the inProduction flag).
 */
@property (readonly) UALogLevel logLevel;

/**
 * The production status of this application. This may be set directly, or it may be determined
 * automatically if the detectProvisioningMode flag is set to `YES`.
 */
@property (readonly, getter=isInProduction) BOOL inProduction;

/**
 * Dictionary of custom config values.
 */
@property (readonly) NSDictionary *customConfig;

@end

NS_ASSUME_NONNULL_END
