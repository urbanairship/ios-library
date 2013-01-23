/*
Copyright 2009-2012 Urban Airship Inc. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
list of conditions and the following disclaimer.

2. Redistributions in binaryform must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided withthe distribution.

THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
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
#import "UAObservable.h"

@class UAAnalytics;
@class UA_ASIHTTPRequest;
@class UALocationService;

UA_VERSION_INTERFACE(AirshipVersion)

/**
 * Key for the default preferences dictionary that 
 * is loaded into NSUserDefaults on start for location services
 */
extern NSString * const UALocationServicePreferences;

/**
 * The takeOff options key for setting custom AirshipConfig options. The value
 * must be an NSDictionary.
 */
extern NSString * const UAirshipTakeOffOptionsAirshipConfigKey;

/**
 * The takeOff options key for passing in the options dictionary provided
 * by [UIApplication application:didFinishLaunchingWithOptions]. This key/value
 * pair must always be included in the takeOff options.
 */
extern NSString * const UAirshipTakeOffOptionsLaunchOptionsKey;

/**
 * The takeOff options key for setting custom analytics options. The value must be
 * an NSDictionary with keys for UAAnalytics. This value is typically not used.
 */
extern NSString * const UAirshipTakeOffOptionsAnalyticsKey;

/**
 * The takeOff options key for setting a pre-exising UAUAser username. The value must be
 * an NSString.
 */
extern NSString * const UAirshipTakeOffOptionsDefaultUsernameKey;

/**
 * The takeOff options key for setting a pre-exising UAUser password. The value must be
 * an NSString.
 */
extern NSString * const UAirshipTakeOffOptionsDefaultPasswordKey;

/**
 * The takeOff method must be called on the main thread. Not doing so results in 
 * this exception being thrown.
 */
extern NSString * const UAirshipTakeOffBackgroundThreadException;

/**
 * UAirship manages the shared state for all Urban Airship services. [UAirship takeOff:] should be
 * called from [UIApplication application:didFinishLaunchingWithOptions] to initialize the shared
 * instance.
 */
@interface UAirship : NSObject {
    
  @private
    NSString *server;
    NSString *appId;
    NSString *appSecret;

    BOOL ready;
    
}

/**
 * The current APNS/remote notification device token.
 */
@property (nonatomic, readonly) NSString *deviceToken;

/**
 * The shared analytics manager. There are not currently any user-defined events,
 * so this is for internal library use only at this time.
 */
@property (nonatomic, retain) UAAnalytics *analytics;

/**
 * The Urban Airship API server. Defaults to https://device-api.urbanairship.com.
 */
@property (nonatomic, copy) NSString *server;

/**
 * The current Urban Airship app key. This value is loaded from the `AirshipConfig.plist` file or
 * an NSDictionary passed in to [UAirship takeOff:] with the
 * UAirshipTakeOffOptionsAirshipConfigKey. If `APP_STORE_OR_AD_HOC_BUILD` is set to `YES`, the value set
 * in `PRODUCTION_APP_KEY` will be used. If `APP_STORE_OR_AD_HOC_BUILD` is set to `NO`, the value set in
 * `DEVELOPMENT_APP_KEY` will be used.
 */
@property (nonatomic, copy) NSString *appId;

/**
 * The current Urban Airship app secret. This value is loaded from the AirshipConfig.plist file or
 * an NSDictionary passed in to `[UAirship takeOff:]` with the
 * `UAirshipTakeOffOptionsAirshipConfigKey`. If `APP_STORE_OR_AD_HOC_BUILD` is set to `YES`, the value set
 * in `PRODUCTION_APP_SECRET` will be used. If `APP_STORE_OR_AD_HOC_BUILD` is set to `NO`, the value set in
 * `DEVELOPMENT_APP_SECRET` will be used.
 */
@property (nonatomic, copy) NSString *appSecret;

/**
 * This flag is set to `YES` if the shared instance of
 * UAirship has been initialized and is ready for use.
 */
@property (nonatomic, assign) BOOL ready;

///---------------------------------------------------------------------------------------
/// @name Location Services
///---------------------------------------------------------------------------------------

@property (nonatomic, retain, getter = locationService) UALocationService *locationService;
- (UALocationService *)locationService;

///---------------------------------------------------------------------------------------
/// @name Logging
///---------------------------------------------------------------------------------------

/**
 * Enables or disables logging. Logging is enabled by default, though the log level must still be set
 * to an appropriate value. This flag overrides the AirshipConfig settings if called after takeOff.
 *
 * @param enabled If YES, console logging is enabled.
 */
+ (void)setLogging:(BOOL)enabled;

/**
 * Sets the log level for the Urban Airship library. The log level defaults to UALogLevelDebug
 * for development apps, and UALogLevelError for production apps (when the APP_STORE_OR_AD_HOC_BUILD
 * AirshipConfig flag is set to YES). Setting LOG_LEVEL in the AirshipConfig settings will override
 * these defaults, but will not override a value set with this method.
 * 
 * @param level The desired UALogLevel value.
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
 * This method must be called from your application delegate's
 * application:didFinishLaunchingWithOptions: method, and it may be called
 * only once. The UIApplication options passed in on launch MUST be included in this method's options
 * parameter with the UAirshipTakeOffOptionsLaunchOptionsKey.
 *
 * Configuration are read from the AirshipConfig.plist file. You may overrride the
 * AirshipConfig.plist values at runtime by including an NSDictionary containing the override
 * values with the UAirshipTakeOffOptionsAirshipConfigKey.
 *
 * @see UAirshipTakeOffOptionsAirshipConfigKey
 * @see UAirshipTakeOffOptionsLaunchOptionsKey
 * @see UAirshipTakeOffOptionsAnalyticsKey
 * @see UAirshipTakeOffOptionsDefaultUsernameKey
 * @see UAirshipTakeOffOptionsDefaultPasswordKey
 *
 * @param options An NSDictionary containing UAirshipTakeOffOptions[...] keys and values. This
 * dictionary MUST contain the UIApplication launch options.
 *
 * @warning takeOff: must be called on the main thread. Not doing so results in an UAirshipTakeOffMainThreadException
 *
 */
+ (void)takeOff:(NSDictionary *)options;

/**
 * Perform teardown on the shared instance. This should be called when an application
 * terminates.
 */
+ (void)land;

/**
 * Returns the shared UAirship instance. This will raise an exception
 * if [UAirship takeOff:] has not been called.
 *
 * @return The shared UAirship instance.
 */
+ (UAirship *)shared;

///---------------------------------------------------------------------------------------
/// @name APNS Device Token Registration
///---------------------------------------------------------------------------------------

/*
 * Register a device token with UA. This will register a device token without an alias or tags.
 * If an alias is set on the device token, it will be removed. Tags will not be changed.
 *
 * Add a UARegistrationObserver to UAPush to receive success or failure callbacks.
 *
 * @param token The device token to register.
 * @warning Deprecated: Use the method on UAPush instead
 */
- (void)registerDeviceToken:(NSData *)token UA_DEPRECATED(__UA_LIB_1_3_0__);

/*
 * Register the current device token with UA.
 *
 * @param info An NSDictionary containing registraton keys and values. See
 * http://urbanairship.com/docs/push.html#registration for details.
 *
 * Add a UARegistrationObserver to UAPush to receive success or failure callbacks.
 * @warning Deprecated: Use the method on UAPush instead
 */
- (void)registerDeviceTokenWithExtraInfo:(NSDictionary *)info UA_DEPRECATED(__UA_LIB_1_3_0__);

/*
 * Register a device token and alias with UA.  An alias should only have a small
 * number (< 10) of device tokens associated with it. Use the tags API for arbitrary
 * groupings.
 *
 * Add a UARegistrationObserver to UAPush to receive success or failure callbacks.
 *
 * @param token The device token to register.
 * @param alias The alias to register for this device token.
 * @warning Deprecated: Use the method on UAPush instead
 */
- (void)registerDeviceToken:(NSData *)token withAlias:(NSString *)alias UA_DEPRECATED(__UA_LIB_1_3_0__);

/*
 * Register a device token with a custom API payload.
 *
 * Add a UARegistrationObserver to UAPush to receive success or failure callbacks.
 *
 * @param token The device token to register.
 * @param info An NSDictionary containing registraton keys and values. See
 * https://docs.urbanairship.com/display/DOCS/Server%3A+iOS+Push+API for details.
 * @warning Deprecated: Use the method on UAPush instead
 */
- (void)registerDeviceToken:(NSData *)token withExtraInfo:(NSDictionary *)info UA_DEPRECATED(__UA_LIB_1_3_0__);

/*
 * Remove this device token's registration from the server.
 * This call is equivalent to an API DELETE call, as described here:
 * http://urbanairship.com/docs/push.html#registration
 *
 * Add a UARegistrationObserver to UAPush to receive success or failure callbacks.
 * @warning Deprecated: Use the pushEnabled property on UAPush instead
 */
- (void)unRegisterDeviceToken UA_DEPRECATED(__UA_LIB_1_3_0__);

@end
