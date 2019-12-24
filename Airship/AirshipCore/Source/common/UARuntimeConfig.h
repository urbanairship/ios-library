/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

#import "UAGlobal.h"

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
 * An array of UAWhitelist entry strings. The whitelist used for validating URLs for landing pages,
 * wallet action, open external URL action, deep link action (if delegate is not set), and
 * HTML in-app messages.
 *
 * @note See UAWhitelist for pattern entry syntax.
 */
@property (readonly) NSArray<NSString *> *whitelist;

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
@property (readonly) NSString *deviceAPIURL;

/**
 * The Airship analytics API url.
 *
 * @note This option is reserved for internal debugging. :nodoc:
 */
@property (readonly) NSString *analyticsURL;

/**
 * The Airship remote data url.
 *
 * @note This option is reserved for internal debugging. :nodoc:
 */
@property (readonly) NSString *remoteDataAPIURL;

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
 * Defaults to `YES`.
 */
@property (readonly, getter=isChannelCaptureEnabled) BOOL channelCaptureEnabled;

/**
 * Enables or disables whitelist checks at the scope `UAWhitelistScopeOpenURL`. If disabled,
 * all whitelist checks for this scope will be allowed.
 *
 * Defaults to `NO`.
 */
@property (readonly, getter=isOpenURLWhitelistingEnabled) BOOL openURLWhitelistingEnabled;

/**
 * Flag indicating whether delayed channel creation is enabled. If set to `YES` channel
 * creation will not occur until channel creation is manually enabled.
 *
 * Defaults to `NO`.
 */
@property (readonly, getter=isChannelCreationDelayEnabled) BOOL channelCreationDelayEnabled;

/**
 * If set to 'YES', the Airship SDK will request authorization to use
 * notifications from the user. Apps that set this flag to `NO` are
 * required to request authorization themselves.
 *
 * Defaults to `YES`.
 */
@property (readonly) BOOL requestAuthorizationToUseNotifications;

/**
 *  Flag indicating whether the data opt-in is enabled.
*/
@property (readonly, getter=isDataOptInEnabled) BOOL dataOptInEnabled;

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
