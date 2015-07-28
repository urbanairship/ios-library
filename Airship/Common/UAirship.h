/*
 Copyright 2009-2015 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "UAGlobal.h"
#import "UAJavaScriptDelegate.h"
#import "UAWhitelist.h"

@class UAConfig;
@class UAAnalytics;
@class UALocationService;
@class UAApplicationMetrics;
@class UAPush;
@class UAUser;
@class UAInbox;
@class UAActionRegistry;
@class UAInAppMessaging;

UA_VERSION_INTERFACE(UAirshipVersion)

/**
 * The takeOff method must be called on the main thread. Not doing so results in 
 * this exception being thrown.
 */
extern NSString * const UAirshipTakeOffBackgroundThreadException;

/**
 * UAirship manages the shared state for all Urban Airship services. [UAirship takeOff:] should be
 * called from within your application delegate's `application:didFinishLaunchingWithOptions:` method
 * to initialize the shared instance.
 */
@interface UAirship : NSObject

/**
 * The application configuration. This is set on takeOff.
 */
@property (nonatomic, strong, readonly) UAConfig *config;

/**
 * The shared analytics manager. There are not currently any user-defined events,
 * so this is for internal library use only at this time.
 */
@property (nonatomic, strong, readonly) UAAnalytics *analytics;


/**
 * The default action registry.
 */
@property (nonatomic, strong, readonly) UAActionRegistry *actionRegistry;


/**
 * Stores common application metrics such as last open.
 */
@property (nonatomic, strong, readonly) UAApplicationMetrics *applicationMetrics;

/**
 * This flag is set to `YES` if the application is set up 
 * with the "remote-notification" background mode and is running
 * iOS7 or greater.
 */
@property (nonatomic, assign, readonly) BOOL remoteNotificationBackgroundModeEnabled;


/**
 * A user configurable JavaScript delegate.
 *
 * NOTE: this delegate is not retained.
 */
@property (nonatomic, weak) id<UAJavaScriptDelegate> jsDelegate;

/**
 * The whitelist used for validating webview URLs.
 */
@property (nonatomic, strong, readonly) UAWhitelist *whitelist;


///---------------------------------------------------------------------------------------
/// @name Location Services
///---------------------------------------------------------------------------------------

@property (nonatomic, strong, readonly) UALocationService *locationService;

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
 * Sets the log level for the Urban Airship library. The log level defaults to `UALogLevelDebug`
 * for development apps, and `UALogLevelError` for production apps (when the inProduction
 * AirshipConfig flag is set to `YES`). Values set with this method prior to `takeOff` will be overridden
 * during takeOff.
 * 
 * @param level The desired `UALogLevel` value.
 */
+ (void)setLogLevel:(UALogLevel)level;

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
+ (void)takeOff:(UAConfig *)config;

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
+ (UAirship *)shared;

/**
 * Returns the `UAPush` instance. Used for configuring and managing push
 * notifications.
 *
 * @return The `UAPush` instance.
 */
+ (UAPush *)push;

/**
 * Returns the `UAInbox` instance. Provides access to the inbox messages.
 *
 * @return The `UAInbox` instance.
 */
+ (UAInbox *)inbox;

/**
 * Returns the `UAUser` instance.
 *
 * @return The `UAUser` instance.
 */
+ (UAUser *)inboxUser;

/**
 * Returns the `UAInAppMessaging` instance. Used for customizing
 * in-app notifications.
 */
+ (UAInAppMessaging *)inAppMessaging;

@end
