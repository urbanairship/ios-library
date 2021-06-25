/* Copyright Airship and Contributors */

#import "UAGlobal.h"
#import "UALocationProvider.h"
#import "UAURLAllowList.h"

// Frameworks
#import <SystemConfiguration/SystemConfiguration.h>
#import <CoreData/CoreData.h>
#import <Security/Security.h>
#import <QuartzCore/QuartzCore.h>
#import <Availability.h>
#import <UserNotifications/UserNotifications.h>

#import "UAConfig.h"

#if !TARGET_OS_TV    // CoreTelephony and WebKit not supported in tvOS
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#import <WebKit/WebKit.h>
#import "UAJavaScriptCommandDelegate.h"
#endif

@class UAConfig;
@class UAAnalytics;
@class UAApplicationMetrics;
@class UAPush;
@class UAUser;
@class UANamedUser;
@class UAActionRegistry;
@class UAChannelCapture;
@class UARemoteDataManager;
@class UAChannel;
@class UAComponent;
@class UALocaleManager;
@class UAPrivacyManager;
@class UAContact;

//---------------------------------------------------------------------------------------
// UADeepLinkDelegate Protocol
//---------------------------------------------------------------------------------------

/**
 * Protocol to be implemented by deep link handlers.
 */
@protocol UADeepLinkDelegate<NSObject>

@optional

/**
 * Called when a deep link has been triggered from Airship. If implemented, the delegate is responsible for processing the provided url.
 *
 * @param url The url for the deep link.
 * @param completionHandler The completion handler to execute when the deep link processing is complete.
 */
-(void)receivedDeepLink:(nonnull NSURL *)url completionHandler:(nonnull void (^)(void))completionHandler;

@end


NS_ASSUME_NONNULL_BEGIN

/**
 * The takeOff method must be called on the main thread. Not doing so results in 
 * this exception being thrown.
 */
extern NSString * const UAirshipTakeOffBackgroundThreadException;
/**
 * NSNotification posted when Airship is ready.
 */
extern NSString * const UAAirshipReadyNotification;

/**
 * UAirship manages the shared state for all Airship services. [UAirship takeOff:] should be
 * called from within your application delegate's `application:didFinishLaunchingWithOptions:` method
 * to initialize the shared instance.
 */
@interface UAirship : NSObject

/**
 * The application configuration.
 */
@property (nonatomic, strong, readonly) UARuntimeConfig *config;

/**
 * The default action registry.
 */
@property (nonatomic, strong, readonly) UAActionRegistry *actionRegistry;

/**
 * Stores common application metrics such as last open.
 */
@property (nonatomic, strong, readonly) UAApplicationMetrics *applicationMetrics;

/**
 * Returns the location provider. Requires the `AirshipLocation` module, otherwise nil.
 * @note For internal use only. :nodoc:
 *
 * @return The `UALocationProvider` instance.
 */
@property (nullable, nonatomic, strong, readonly) id<UALocationProvider> locationProvider;

/**
 * This flag is set to `YES` if the application is set up 
 * with the "remote-notification" background mode
 */
@property (nonatomic, assign, readonly) BOOL remoteNotificationBackgroundModeEnabled;

#if !TARGET_OS_TV

/**
 * A user configurable UAJavaScriptCommandDelegate.
 *
 * NOTE: this delegate is not retained.
 */
@property (nonatomic, weak, nullable) id<UAJavaScriptCommandDelegate> javaScriptCommandDelegate;

/**
 * The channel capture utility.
 */
@property (nonatomic, strong, readonly) UAChannelCapture *channelCapture;

#endif

/**
 * A user configurable deep link delegate.
 *
 * NOTE: this delegate is not retained.
 */
@property (nonatomic, weak, nullable) id<UADeepLinkDelegate> deepLinkDelegate;


/**
 * The URL allow list used for validating URLs for landing pages, wallet action, open external URL action,
 * deep link action (if delegate is not set), and HTML in-app messages.
 */
@property (nonatomic, strong, readonly) UAURLAllowList *URLAllowList;


/**
 * Analytics instance.
 */
@property (nonatomic, strong, readonly) UAAnalytics *analytics;

/**
 * Locale instance.
 */
@property (nonatomic, strong, readonly) UALocaleManager *locale;

/**
 * Privacy manager instance.
 */
@property (nonatomic, strong, readonly) UAPrivacyManager *privacyManager;

/**
 * Global data collection flag. Enabled by default, unless `UAConfig.dataCollectionOptInEnabled`
 * is set to `YES` on the first run.
 *
 * When disabled, the device will stop collecting and sending data for named user, events,
 * tags, attributes, associated identifiers, and location from the device.
 *
 * Push notifications will continue to work only if `UAPush.pushTokenRegistrationEnabled`
 * has been explicitly set to `YES`, otherwise it will default to the current state  of `isDataCollectionEnabled`.
 *
 * @note To disable by default, set the `UAConfig.dataCollectionOptInEnabled` flag to `YES` on the first run.
 * @deprecated Deprecated – to be removed in SDK version 15.0. Please use the Privacy Manager.
 */
@property (nonatomic, assign, getter=isDataCollectionEnabled) BOOL dataCollectionEnabled DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 15.0. Please use the Privacy Manager.");

///---------------------------------------------------------------------------------------
/// @name Logging
///---------------------------------------------------------------------------------------

/**
 * Enables or disables logging. Logging is enabled by default, though the log level must still be set
 * to an appropriate value.
 *
 * @param enabled If `YES`, console logging is enabled.
 */
+ (void)setLogging:(BOOL)enabled;

/**
 * Sets the log level for the Airship library. The log level defaults to `UALogLevelDebug`
 * for development apps, and `UALogLevelError` for production apps (when the inProduction
 * AirshipConfig flag is set to `YES`). Values set with this method prior to `takeOff` will be overridden
 * during takeOff.
 * 
 * @param level The desired `UALogLevel` value.
 */
+ (void)setLogLevel:(UALogLevel)level;

/**
 * Enables or disables logging implementation errors with emoji to make it stand
 * out in the console. It is enabled by default, and will be disabled for production
 * applications.
 *
 * @param enabled If `YES`, loud implementation error logging is enabled.
 */
+ (void)setLoudImpErrorLogging:(BOOL)enabled;

///---------------------------------------------------------------------------------------
/// @name Lifecycle
///---------------------------------------------------------------------------------------

/**
 * Initializes UAirship and performs all necessary setup. This creates the shared instance, loads
 * configuration values, initializes the analytics/reporting
 * module and creates a UAUser if one does not already exist.
 * 
 * This method *must* be called from your application delegate's
 * `application:didFinishLaunchingWithOptions:` method, and it may be called
 * only once.
 *
 * @warning `takeOff:` must be called on the main thread. This method will throw
 * an `UAirshipTakeOffMainThreadException` if it is run on a background thread.
 * @param config The populated UAConfig to use.
 *
 */
+ (void)takeOff:(nullable UAConfig *)config;

/**
 * Simplified `takeOff` method that uses `AirshipConfig.plist` for initialization.
 */
+ (void)takeOff;

///---------------------------------------------------------------------------------------
/// @name Instance Accessors
///---------------------------------------------------------------------------------------

/**
 * Returns the `UAirship` instance.
 *
 * @return The `UAirship` instance.
 */
+ (null_unspecified UAirship *)shared;

/**
 * Returns the UAChannel instance. Used for channel registration and
 * tag APIs.
 *
 * @return The `UAChannel` instance.
 */
+ (null_unspecified UAChannel *)channel;

/**
 * Returns the `UAPush` instance. Used for configuring and managing push
 * notifications.
 *
 * @return The `UAPush` instance.
 */
+ (null_unspecified UAPush *)push;

/**
 * Returns the `UANamedUser` instance.
 *
 * @return The `UANamedUser` instance.
 */
+ (null_unspecified UANamedUser *)namedUser;

/**
 * Returns the `UAContact` instance.
 *
 * @return The `UAContact` instance.
 */
+ (null_unspecified UAContact *)contact;

/**
 * Returns the default `UAAnalytics` instance.
 *
 * @return The `UAAnalytics` instance.
 */
+ (null_unspecified UAAnalytics *)analytics;

/**
 * Returns an UAComponent for a given class name.
 * @note For internal use only. :nodoc:
 *
 * @param className The classname of the component.
 * @return The component, or nil if the component is not available.
 */
- (nullable UAComponent *)componentForClassName:(NSString *)className;

NS_ASSUME_NONNULL_END


@end
