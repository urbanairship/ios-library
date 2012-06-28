/*
 Copyright 2009-2012 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

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
#import "UAirship.h"
#import "UAObservable.h"



#define PUSH_UI_CLASS @"UAPushUI"
#define PUSH_DELEGATE_CLASS @"UAPushNotificationHandler"

UA_VERSION_INTERFACE(UAPushVersion)

@protocol UAPushUIProtocol
+ (void)openApnsSettings:(UIViewController *)viewController
                   animated:(BOOL)animated;
+ (void)openTokenSettings:(UIViewController *)viewController //TODO: remove from lib - it's a demo feature
                   animated:(BOOL)animated;
+ (void)closeApnsSettingsAnimated:(BOOL)animated;
+ (void)closeTokenSettingsAnimated:(BOOL)animated;//TODO: remove from lib - it's a demo feature
@end


/**
 * Protocol to be implemented by push notification clients. All methods are optional.
 */
@protocol UAPushNotificationDelegate<NSObject>

@optional

/**
 * Called when an alert notification is received.
 * @param alertMessage a simple string to be displayed as an alert
 */
- (void)displayNotificationAlert:(NSString *)alertMessage;

/**
 * Called when an alert notification is received with additional localization info.
 * @param alertDict a dictionary containing the alert and localization info
 */
- (void)displayLocalizedNotificationAlert:(NSDictionary *)alertDict;

/**
 * Called when a push notification is received with a sound associated
 * @param sound the sound to play
 */
- (void)playNotificationSound:(NSString *)sound;

/**
 * Called when a push notification is received with a custom payload
 * @param notification basic information about the notification
 * @param customPayload user-defined custom payload
 */
- (void)handleNotification:(NSDictionary *)notification withCustomPayload:(NSDictionary *)customPayload;

/**
 * Called when a push notification is received with a badge number
 * @param badgeNumber the badge number to display
 */
- (void)handleBadgeUpdate:(int)badgeNumber;

/**
 * Called when a push notification is received when the application is in the background
 * @param notification the push notification
 */
- (void)handleBackgroundNotification:(NSDictionary *)notification;
@end

/**
 * Implement this protocol and register with the UAirship shared instance to receive
 * device token registration success and failure callbacks.
 */
@protocol UARegistrationObserver
@optional
- (void)registerDeviceTokenSucceeded;
- (void)registerDeviceTokenFailed:(UA_ASIHTTPRequest *)request;
- (void)unRegisterDeviceTokenSucceeded;
- (void)unRegisterDeviceTokenFailed:(UA_ASIHTTPRequest *)request;
- (void)addTagToDeviceSucceeded;
- (void)addTagToDeviceFailed:(UA_ASIHTTPRequest *)request;
- (void)removeTagFromDeviceSucceeded;
- (void)removeTagFromDeviceFailed:(UA_ASIHTTPRequest *)request;
@end

/** This singleton is represents the functionality provided by the Urban Airship client Push API*/

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
 * @see UAPushUI
 *
 * @param customUIClass An implementation of UAPushUIProtocol
 */
+ (void)useCustomUI:(Class)customUIClass;
+ (void)openApnsSettings:(UIViewController *)viewController
                animated:(BOOL)animated;
+ (void)openTokenSettings:(UIViewController *)viewController
                 animated:(BOOL)animated;
+ (void)closeApnsSettingsAnimated:(BOOL)animated;
+ (void)closeTokenSettingsAnimated:(BOOL)animated;

///---------------------------------------------------------------------------------------
/// @name UAPush
///---------------------------------------------------------------------------------------

/** Set a delegate that implements the UAPushNotifcationDelegate protocol. If not
 set, a default is provided */
@property (nonatomic, assign) id<UAPushNotificationDelegate> delegate;

/** Notification types this device is registered for */
@property (nonatomic, readonly) UIRemoteNotificationType notificationTypes;

/** Clean up when app is terminated, you should not need to call this unless you are working
 outside of UAirship. The UAirship land method calls this method. */

+ (void)land;

///---------------------------------------------------------------------------------------
/// @name Push Notifications
///---------------------------------------------------------------------------------------


/** Enables/disables push notifications on this device through Urban Airship */
@property (nonatomic, getter = pushEnabled,
           setter = setPushEnabled:) BOOL pushEnabled;


/** The device token for this device, as a string */
@property (nonatomic, copy, getter = deviceToken,
           setter = setDeviceToken:) NSString *deviceToken;

/** Returns YES if the device token has changed. This method is scheduled for removal 
 in the short term, it is recommended that you do not use it. */
@property (nonatomic, assign, readonly) BOOL deviceTokenHasChanged UA_DEPRECATED(__LIB_1_3_0__);


///---------------------------------------------------------------------------------------
/// @name Autobadge
///---------------------------------------------------------------------------------------


@property (nonatomic, assign, getter = autobadgeEnabled,
           setter = setAutobadgeEnabled:) BOOL autobadgeEnabled;

/** Sets the badge number on the device and 
 on the Urban Airship server 
 
 @param badgeNumber The number to set the badge to
 */
- (void)setBadgeNumber:(NSInteger)badgeNumber;

/** Resets the badge to zero (0) both on the
 device and on Urban Airships servers. Convenience method
 for setBadgeNumber:0
 */
- (void)resetBadge;

/** Enable the Urban Airship autobadge feature 
 
 @param enabled New value
 @warning *Deprecated* Use the setAutobadgeEnabled: method instead
 */

- (void)enableAutobadge:(BOOL)enabled UA_DEPRECATED(__LIB_1_3_0__);


///---------------------------------------------------------------------------------------
/// @name Alias
///---------------------------------------------------------------------------------------
 
 /** Alias for this device */
@property (nonatomic, copy, getter = alias,
           setter = setAlias:) NSString *alias;

///---------------------------------------------------------------------------------------
/// @name Tags
///---------------------------------------------------------------------------------------

/** Tags for this device. */
@property (nonatomic, copy, getter = tags,
           setter = setTags:) NSArray *tags;

/** Allows tag editing from device. Set this to NO to prevent the device
 from sending any tag information to the server when using server side tagging
 */
@property (nonatomic, assign, getter = canEditTagsFromDevice,
           setter = setCanEditTagsFromDevice:) BOOL canEditTagsFromDevice; 

/** Adds a tag to the list of tags for the device
 To update the server, make all of you changes, then call
 [[UAPush shared] updateRegisration] to update the UA server.
 
 @param tag Tag to be added
 @warning *Warning* When updating several 
 server side values (tags, alias, time zone, quiettime) set the values first, then
 call the updateRegistration method. Batching these calls improves API and client performance.
 */
- (void)addTagToCurrentDevice:(NSString *)tag;

/** Adds a group of tags to the current list of 
 device tags.  To update the server, make all of you changes, then call
 updateRegistration
 
 @param tags Array of new tags
 @warning *Warning* When updating several 
 server side values (tags, alias, time zone, quiettime) set the values first, then
 call the updateRegistration method. Batching these calls improves API and client performance.
 */

- (void)addTagsToCurrentDevice:(NSArray*)tags;

/** Removes a tag from the current tag list. To update the server, make all of you changes, then call
 updateRegistration
 
 @param tag Tag to be removed
 @warning *Warning* When updating several 
 server side values (tags, alias, time zone, quiettime) set the values first, then
 call the updateRegistration method. Batching these calls improves API and client performance.
 */
- (void)removeTagFromCurrentDevice:(NSString *)tag;

/** Removes a group of tags from a device.  To update the server, make all of you changes, then call
 updateRegisration
 
 @param tags Array of tags to be removed
 @warning *Warning* When updating several 
 server side values (tags, alias, time zone, quiettime) set the values first, then
 call updateRegistration. Batching these calls improves API and client performance.
 */
- (void)removeTagsFromCurrentDevice:(NSArray*)tags;

/** Updates the tag list on the device and on Urban Airship. Use setTags:
 instead. This method updates the server after setting the tags. Use
 the other tag manipulation methods instead, and update the server
 when appropriate.
 
 @param values The new tag values
 @warning *Warning* When updating several 
 server side values (tags, alias, time zone, quiettime) set the values first, then
 call updateRegistration. Batching these calls improves API and client performance.
 */
- (void)updateTags:(NSMutableArray *)values UA_DEPRECATED(__LIB_1_3_0__);

///---------------------------------------------------------------------------------------
/// @name Time Zone
///---------------------------------------------------------------------------------------

/** Time Zone for the device */
@property (nonatomic, retain, getter = timeZone,
           setter = setTimeZone:) NSTimeZone *timeZone;

/** The current time zone setting
 @return The time zone name
 */
- (NSString *)tz UA_DEPRECATED(__LIB_1_3_0__);

/** Set a new time zone for the device
 @param tz NSString representing the new time zone name. If the name does not resolve to an actual NSTimeZone,
 the default time zone [NSTimeZone localTimeZone] is used
 */
- (void)setTz:(NSString *)tz UA_DEPRECATED(__LIB_1_3_0__);

///---------------------------------------------------------------------------------------
/// @name Alias
///---------------------------------------------------------------------------------------


/** Updates the alias on the device and on Urban Airship. Use only 
 when the alias is the only value that needs to be updated. 

 @param value Updated alias
 @warning *Warning* When updating several 
 server side values (tags, alias, time zone, quiettime) set the values first, then
 call updateRegistration. Batching these calls improves API and client performance.
 */
- (void)updateAlias:(NSString *)value UA_DEPRECATED(__LIB_1_3_0__);

///---------------------------------------------------------------------------------------
/// @name Quiet Time
///---------------------------------------------------------------------------------------

/** Quiet time settings for this device */
@property (nonatomic, copy, readonly, getter = quietTime) NSDictionary *quietTime;

/** Change quiet time for current device token, only take hh:mm into account
 @param from Date for start of quiet time
 @param to Date for end of quiet time
 @param tz Time zone the dates are in reference to
*/
- (void)setQuietTimeFrom:(NSDate *)from to:(NSDate *)to withTimeZone:(NSTimeZone *)tz;

/** Disables quiet time settings */
- (void)disableQuietTime;


///---------------------------------------------------------------------------------------
/// @name Urban Airship Device Token Registration
///---------------------------------------------------------------------------------------

/** This registers the device token and all current associated Urban Airship custom
 features that are currently set.

 Features set with this call if available:
 
 - tags
 - alias
 - time zone
 - autobadge

 Add a UARegistrationObserver to UAirship to receive success or failure callbacks.
 @param token The device token to register.
 */
- (void)registerDeviceToken:(NSData *)token;

/**
  Register the current device token with UA.
 
  @param info An NSDictionary containing registration keys and values. See
  http://urbanairship.com/docs/push.html#registration for details.
 
  Add a UARegistrationObserver to UAPush to receive success or failure callbacks.
*/
- (void)registerDeviceTokenWithExtraInfo:(NSDictionary *)info;

/**
  Register a device token and alias with UA.  An alias should only have a small
  number (< 10) of device tokens associated with it. Use the tags API for arbitrary
  groupings.
 
  Add a UARegistrationObserver to UAPush to receive success or failure callbacks.
 
  @param token The device token to register.
  @param alias The alias to register for this device token.
*/
- (void)registerDeviceToken:(NSData *)token withAlias:(NSString *)alias;

/**
 Register a device token with a custom API payload.

 Add a UARegistrationObserver to UAPush to receive success or failure callbacks.

 @param token The device token to register.
 @param info An NSDictionary containing registration keys and values. See
 https://docs.urbanairship.com/display/DOCS/Server%3A+iOS+Push+API for details.
*/
- (void)registerDeviceToken:(NSData *)token withExtraInfo:(NSDictionary *)info;

/**
 Remove this device token's registration from the server.
 This call is equivalent to an API DELETE call, as described here:
 https://docs.urbanairship.com/display/DOCS/Server%3A+iOS+Push+API#ServeriOSPushAPI-Registration
 
 Add a UARegistrationObserver to UAPush to receive success or failure callbacks.
*/
- (void)unRegisterDeviceToken;

/** Register the device for remote notifications (see Apple documentation for more
 detail)
 @param types Bitmask of notification types
 */
- (void)registerForRemoteNotificationTypes:(UIRemoteNotificationType)types;

/** Registers or updates the current registration. If push notifications are not enabled,
 this unregisters the device token */
- (void)updateRegistration;

///---------------------------------------------------------------------------------------
/// @name Push Notification UI Methods
///---------------------------------------------------------------------------------------

//Handle incoming push notifications
- (void)handleNotification:(NSDictionary *)notification applicationState:(UIApplicationState)state;

+ (NSString *)pushTypeString:(UIRemoteNotificationType)types;

///---------------------------------------------------------------------------------------
/// @name NSUserDefaults
///---------------------------------------------------------------------------------------

/** Register the user defaults for this class. You should not need to call this method
 unless you are bypassing UAirship
 */
+ (void)registerNSUserDefaults;

@end
