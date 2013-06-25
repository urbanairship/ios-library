/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

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
#import "UAHTTPConnection.h"

#define PUSH_UI_CLASS @"UAPushUI"
#define PUSH_DELEGATE_CLASS @"UAPushNotificationHandler"

/**
 * Implement this protocol to provide a custom UI for use with UAPush. The default
 * implementation, UAPushUI, is provided in the library's sample UI distribution.
 */
@protocol UAPushUIProtocol

/**
 * Open a push settings screen. The default implementation provides settings for toggling push
 * on and off and managing quiet time.
 *
 * @param viewController The parent view controller.
 * @param animated `YES` to animate the display, otherwise `NO`
 */
+ (void)openApnsSettings:(UIViewController *)viewController
                animated:(BOOL)animated;

/**
 * Close the push settings screen.
 *
 * @param animated `YES` to animate the view transition, otherwise `NO`
 */
+ (void)closeApnsSettingsAnimated:(BOOL)animated;

@end


/**
 * Protocol to be implemented by push notification clients. All methods are optional.
 */
@protocol UAPushNotificationDelegate<NSObject>

@optional

/**
 * Called when an alert notification is received in the foreground.
 * @param alertMessage a simple string to be displayed as an alert
 */
- (void)displayNotificationAlert:(NSString *)alertMessage;

/**
 * Called when an alert notification is received in the foreground with additional localization info.
 * @param alertDict a dictionary containing the alert and localization info
 */
- (void)displayLocalizedNotificationAlert:(NSDictionary *)alertDict;

/**
 * Called when a push notification is received in the foreground with a sound associated
 * @param soundFilename The sound file to play or `default` for the standard notification sound.
 *        This file must be included in the application bundle.
 */
- (void)playNotificationSound:(NSString *)soundFilename;


/**
 * Called when a push notification is received in the foreground with a badge number.
 * @param badgeNumber The badge number to display
 */
- (void)handleBadgeUpdate:(NSInteger)badgeNumber;

/**
 * Called when a push notification is received while the app is running in the foreground
 * @param notification basic information about the notification
 */
- (void)receivedForegroundNotification:(NSDictionary *)notification;


/**
 * Called when the app is started or resumed because a user opened a notification.
 * @param notification the push notification
 */
- (void)launchedFromNotification:(NSDictionary *)notification;
@end

/**
 * Implement this protocol and register with the UAPush shared instance to receive
 * device token registration success and failure callbacks.
 */
@protocol UARegistrationObserver
@optional
- (void)registerDeviceTokenSucceeded;
- (void)registerDeviceTokenFailed:(UAHTTPRequest *)request;
- (void)unRegisterDeviceTokenSucceeded;
- (void)unRegisterDeviceTokenFailed:(UAHTTPRequest *)request;
@end

/**
 * This singleton provides an interface to the functionality provided by the Urban Airship iOS Push API.
 */
@interface UAPush : UAObservable


SINGLETON_INTERFACE(UAPush);

///---------------------------------------------------------------------------------------
/// @name UAPush UI
///---------------------------------------------------------------------------------------


/**
 * Use a custom UI implementation.
 * Replaces the default push UI, defined in UAPushUI, with
 * a custom implementation.
 *
 * @see UAPushUIProtocol
 *
 * @param customUIClass An implementation of UAPushUIProtocol
 */
+ (void)useCustomUI:(Class)customUIClass;

/**
 * Open the push settings screen. The default implementation provides settings for toggling push
 * on and off and managing quiet time.
 *
 * @param viewController The parent view controller.
 * @param animated `YES` to animate the display, otherwise `NO`
 */
+ (void)openApnsSettings:(UIViewController *)viewController
                animated:(BOOL)animated;

/**
 * Close the push settings screen.
 *
 * @param animated `YES` to animate the view transition, otherwise `NO`
 */
+ (void)closeApnsSettingsAnimated:(BOOL)animated;


///---------------------------------------------------------------------------------------
/// @name UAPush
///---------------------------------------------------------------------------------------

/** 
 * Set a delegate that implements the UAPushNotificationDelegate protocol. If not
 * set, a default implementation is provided (UAPushNotificationHandler).
 */
@property (nonatomic, assign) id<UAPushNotificationDelegate> delegate;

/** Notification types this app will request from APNS. */
@property (nonatomic, readonly) UIRemoteNotificationType notificationTypes;

/**
 * Clean up when app is terminated. You should not ordinarily call this method as it is called
 * during [UAirship land].
 */
+ (void)land;

///---------------------------------------------------------------------------------------
/// @name Push Notifications
///---------------------------------------------------------------------------------------


/**
 * Enables/disables push notifications on this device through Urban Airship. Defaults to `YES`.
 */
@property (nonatomic) BOOL pushEnabled; /* getter = pushEnabled, setter = setPushEnabled: */


/** 
 * Sets the default value for pushEnabled. The default is `YES`. After the pushEnabled
 * value has been directly set, this value has no effect.
 * @param enabled The default value for push enabled
 */
+ (void)setDefaultPushEnabledValue:(BOOL)enabled;

/** The device token for this device, as a hex string. */
@property (nonatomic, copy, readonly) NSString *deviceToken;


///---------------------------------------------------------------------------------------
/// @name Autobadge
///---------------------------------------------------------------------------------------

/**
 * Toggle the Urban Airship auto-badge feature. Defaults to `NO` If enabled, this will update the
 * badge number stored by UA every time the app is started or foregrounded.
 */
@property (nonatomic, assign) BOOL autobadgeEnabled; /* getter = autobadgeEnabled, setter = setAutobadgeEnabled: */

/**
 * Sets the badge number on the device and on the Urban Airship server.
 * 
 * @param badgeNumber The new badge number
 */
- (void)setBadgeNumber:(NSInteger)badgeNumber;

/**
 * Resets the badge to zero (0) on both the device and on Urban Airships servers. This is a
 * convenience method for `setBadgeNumber:0`.
 */
- (void)resetBadge;

///---------------------------------------------------------------------------------------
/// @name Alias
///---------------------------------------------------------------------------------------
 
/** Alias for this device */
@property (nonatomic, copy) NSString *alias; /* getter = alias, setter = setAlias: */

///---------------------------------------------------------------------------------------
/// @name Tags
///---------------------------------------------------------------------------------------

/** Tags for this device. */
@property (nonatomic, copy) NSArray *tags; /* getter = tags, setter = setTags: */

/**
 * Allows tag editing from device. Set this to `NO` to prevent the device from sending any tag
 * information to the server when using server side tagging. Defaults to `YES`.
 */
@property (nonatomic, assign) BOOL deviceTagsEnabled;

/**
 * Adds a tag to the list of tags for the device.
 * To update the server, make all of your changes, then call
 * `updateRegistration` to update the UA server.
 * 
 * @param tag Tag to be added
 * @warning When updating multiple 
 * server side values (tags, alias, time zone, quiet time) set the values first, then
 * call the updateRegistration method. Batching these calls improves API and client performance.
 */
- (void)addTagToCurrentDevice:(NSString *)tag;

/**
 * Adds a group of tags to the current list of device tags. To update the server, make all of your
 * changes, then call `updateRegistration`.
 * 
 * @param tags Array of new tags
 * @warning When updating multiple 
 * server side values (tags, alias, time zone, quiet time) set the values first, then
 * call the `updateRegistration` method. Batching these calls improves API and client performance.
 */

- (void)addTagsToCurrentDevice:(NSArray *)tags;

/**
 * Removes a tag from the current tag list. To update the server, make all of your changes, then call
 * `updateRegistration`.
 * 
 * @param tag Tag to be removed
 * @warning When updating multiple 
 * server side values (tags, alias, time zone, quiet time) set the values first, then
 * call the `updateRegistration` method. Batching these calls improves API and client performance.
 */
- (void)removeTagFromCurrentDevice:(NSString *)tag;

/**
 * Removes a group of tags from a device. To update the server, make all of your changes, then call
 * `updateRegisration`.
 * 
 * @param tags Array of tags to be removed
 * @warning When updating multiple 
 * server side values (tags, alias, time zone, quiet time) set the values first, then
 * call updateRegistration. Batching these calls improves API and client performance.
 */
- (void)removeTagsFromCurrentDevice:(NSArray *)tags;

///---------------------------------------------------------------------------------------
/// @name Quiet Time
///---------------------------------------------------------------------------------------

/**
 * Quiet time settings for this device.
 */
@property (nonatomic, copy, readonly) NSDictionary *quietTime;

/**
 * Time Zone for quiet time.
 */
@property (nonatomic, retain) NSTimeZone *timeZone; /* getter = timeZone, setter = setTimeZone: */

/**
 * Enables/Disables quiet time
 */
@property (nonatomic, assign) BOOL quietTimeEnabled;

/**
 * Change quiet time for current device token, only take hh:mm into account. Update the server
 * after making changes to the quiet time with the `updateRegistration` call. 
 * Batching these calls improves API and client performance.
 * 
 * @warning *Important* The behavior of this method has changed in as of 1.3.0
 * This method no longer automatically enables quiet time, and does not automatically update
 * the server. Please refer to `quietTimeEnabled` and `updateRegistration` methods for
 * more information
 * 
 * @param from Date for start of quiet time (HH:MM are used)
 * @param to Date for end of quiet time (HH:MM are used)
 * @param tz The time zone for the from and to dates
 */
- (void)setQuietTimeFrom:(NSDate *)from to:(NSDate *)to withTimeZone:(NSTimeZone *)tz;


///---------------------------------------------------------------------------------------
/// @name Registration
///---------------------------------------------------------------------------------------


/**
 * This registers the device token and all current associated Urban Airship custom
 * features that are currently set.
 * 
 * Features set with this call if available:
 *  
 * - tags
 * - alias
 * - quiet time
 * - autobadge
 * 
 * Add a UARegistrationObserver to UAPush to receive success and failure callbacks.
 *
 * @param token The device token to register.
 */
- (void)registerDeviceToken:(NSData *)token;

/**
 * Register the device for remote notifications (see Apple documentation for more
 * detail).
 *
 * @param types Bitmask of UIRemoteNotificationType types
 */
- (void)registerForRemoteNotificationTypes:(UIRemoteNotificationType)types;

/**
 * Registers or updates the current registration with an API call. If push notifications are
 * not enabled, this unregisters the device token.
 *
 * Register an implementation of UARegistrationObserver with UAPush to receive success and failure callbacks.
 */
- (void)updateRegistration;

/** 
 * Automatically retry on errors. Defaults to `YES`. If set to `YES` and there is a recoverable
 * error when connecting to the Urban Airship servers, the library will retry until successful. 
 */
@property (nonatomic, assign) BOOL retryOnConnectionError;

///---------------------------------------------------------------------------------------
/// @name Receiving Notifications
///---------------------------------------------------------------------------------------

/**
 * Handle incoming push notifications. This method will record push conversions, parse the notification
 * and call the appropriate methods on your delegate.
 *
 * @param notification The notification payload, as passed to your application delegate.
 * @param state The application state at the time the notification was received.
 */
- (void)handleNotification:(NSDictionary *)notification applicationState:(UIApplicationState)state;


///---------------------------------------------------------------------------------------
/// @name Push Notification UI Methods
///---------------------------------------------------------------------------------------

/*
 * Returns a human-readable (English-language), comma-separated list of the push notification types.
 *
 * @param types The notification types to include in the list.
 *
 * @return A stringified list of the types.
 */
+ (NSString *)pushTypeString:(UIRemoteNotificationType)types;

@end
