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



@interface UAPush : UAObservable {
    @private
        /* Push notification delegate. Handles incoming notifications */
        id<UAPushNotificationDelegate> delegate_; 
         /* A default implementation of the push notification delegate */
        NSObject<UAPushNotificationDelegate> *defaultPushHandler;
        UIRemoteNotificationType notificationTypes_;
        NSString *deviceToken_;
        BOOL deviceTokenHasChanged_;
        NSUserDefaults *standardUserDefaults_;
}

@property (nonatomic, assign) id<UAPushNotificationDelegate> delegate;

/** Notification types this device is registered for */
@property (nonatomic, readonly) UIRemoteNotificationType notificationTypes;

/** Enables/disables push notifications on this device through Urban Airship */
@property (nonatomic, getter = pushEnabled,
           setter = setPushEnabled:) BOOL pushEnabled;

/** The device token for this device, as a string */
@property (nonatomic, copy, getter = deviceToken,
           setter = setDeviceToken:) NSString *deviceToken;

/** Alias for this device */
@property (nonatomic, copy, getter = alias,
           setter = setAlias:) NSString *alias;

/** Tags for this device */
@property (nonatomic, copy, getter = tags,
           setter = setTags:) NSArray *tags;

/** Quiet time settings for this device */
@property (nonatomic, copy, readonly, getter = quietTime) NSDictionary *quietTime;




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

/** Clean up when app is terminated, you should not need to call this unless you are working
 outside of UAirship. The UAirship land method calls this method. */

+ (void)land;

///---------------------------------------------------------------------------------------
/// @name Autobadge
///---------------------------------------------------------------------------------------


/** Current state of the autobadge. Autobadge allows the use of server side incrementing/decrementing
 of the badge value 
 */
- (BOOL)autobadgeEnabled;

/** Enables or disables the autobadge feature. Autobadge allows the use of server side incrementing/decrementing
 of the badge value 
 @param autobadgeEnabled The new badge value 
 */
- (void)setAutobadgeEnabled:(BOOL)autobadgeEnabled;

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
//- (void)enableAutobadge:(BOOL)enabled __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_NA, __MAC_NA, __IPHONE_3_0, __IPHONE_4_0);

- (void)enableAutobadge:(BOOL)enabled UA_DEPRECATED(__LIB_1_2_2__);
///---------------------------------------------------------------------------------------
/// @name Device Token
///---------------------------------------------------------------------------------------

/** Most recent device token, or nil if the device has not registered for push 
 
 @return The current, or most recent device token */
- (NSString *)deviceToken;

/** Sets the device token. Refer to the parseDeviceToken: method in UAPush for the proper procedure 
 for parsing a device token. You should not need to call this method directly, instead, use one of the 
 registerDeviceToken: methods and the NSData object returned from Apple in the
 application:didRegisterForRemoteNotificationsWithDeviceToken: delegate callback. 
 This method has the side effect of modifying the deviceTokenHasChanged BOOL if the token
 has changed.
 
 @param deviceToken The device token parsed into a string
 */
- (void)setDeviceToken:(NSString *)deviceToken;

/** Whether there has been a change from the previous device token 
 
 @return YES if the device token has changed, NO otherwise */
- (BOOL)deviceTokenHasChanged UA_DEPRECATED(__LIB_1_2_2__); 

///---------------------------------------------------------------------------------------
/// @name Push Settings
///---------------------------------------------------------------------------------------


/** Current setting for Push notifications 
 
 @return BOOL representing wether push is enabled
*/
- (BOOL)pushEnabled;

/** Enables/Disables Push Notifications
 
 @param pushEnabled New value for enabling/disabling push
 */
- (void)setPushEnabled:(BOOL)pushEnabled;

///---------------------------------------------------------------------------------------
/// @name Alias
///---------------------------------------------------------------------------------------


/** Device Alias 
 
 @return The current device alias */
- (NSString*)alias;

/** Set the device alias 
 
 @param alias NSString representing the new alias 
    @warning *Warning* When updating several 
    server side values (tags, alias, time zone, quiettime) set the values first, then
    call the updateUA method. Batching these calls improves API and client perfomance.
 */
- (void)setAlias:(NSString*)alias;

///---------------------------------------------------------------------------------------
/// @name Tags
///---------------------------------------------------------------------------------------

/** Tags associated with this device 
 
 @return The current tags associated with this device or nil
 */
- (NSArray *)tags;

/** Set the tags for this device. This replaces all the current tags with
 the new tags. Make sure to call updateRegistration after modifying the
 tags
 
 @param tags New tags for the device
 @warning *Warning* When updating several 
 server side values (tags, alias, time zone, quiettime) set the values first, then
 call the updateUA method. Batching these calls improves API and client perfomance.
 */
- (void)setTags:(NSArray *)tags;

/** Adds a tag to the list of tags for the device
 To update the server, make all of you changes, then call
 [[UAPush shared] updateRegisration] to update the UA server.
 
 @param tag Tag to be added
 @warning *Warning* When updating several 
 server side values (tags, alias, time zone, quiettime) set the values first, then
 call the updateUA method. Batching these calls improves API and client perfomance.
 */
- (void)addTagToCurrentDevice:(NSString *)tag;

/** Adds a group of tags to the current list of 
 device tags.  To update the server, make all of you changes, then call
 [[UAPush shared] updateRegisration]
 
 @param tags Array of new tags
 @warning *Warning* When updating several 
 server side values (tags, alias, time zone, quiettime) set the values first, then
 call the updateUA method. Batching these calls improves API and client perfomance.
 */

- (void)addTagsToCurrentDevice:(NSArray*)tags;

/** Removes a tag from the current tag list. To update the server, make all of you changes, then call
 [[UAPush shared] updateRegisration]
 
 @param tag Tag to be removed
 @warning *Warning* When updating several 
 server side values (tags, alias, time zone, quiettime) set the values first, then
 call the updateUA method. Batching these calls improves API and client perfomance.
 */
- (void)removeTagFromCurrentDevice:(NSString *)tag;

/** Removes a group of tags from a device.  To update the server, make all of you changes, then call
 [[UAPush shared] updateRegisration]
 
 @param tags Array of tags to be removed
 @warning *Warning* When updating several 
 server side values (tags, alias, time zone, quiettime) set the values first, then
 call the updateUA method. Batching these calls improves API and client perfomance.
 */
- (void)removeTagsFromCurrentDevice:(NSArray*)tags;


/** Updates the tag list on the device and on Urban Airship. Use setTags:
 instead. This method updates the server after setting the tags. Use
 the other tag manipulation methods instead, and update the server
 when appropriate.
 
 @param values The new tag values
 @warning *Warning* When updating several 
 server side values (tags, alias, time zone, quiettime) set the values first, then
 call the updateUA method. Batching these calls improves API and client perfomance.
 */
- (void)updateTags:(NSMutableArray *)value UA_DEPRECATED(__LIB_1_2_2__);

///---------------------------------------------------------------------------------------
/// @name Time Zone
///---------------------------------------------------------------------------------------

/** Current time zone used for notification purposes
 @return The current time zone
 */
- (NSTimeZone *)timeZone;

/** Sets the time zone for notification purposes. To update the server, make all of you changes, then call
 [[UAPush shared] updateRegisration]
 
 @param timeZone The new time zone.
 @warning *Warning* When updating several 
 server side values (tags, alias, time zone, quiettime) set the values first, then
 call the updateUA method. Batching these calls improves API and client perfomance.
 */
- (void)setTimeZone:(NSTimeZone *)timeZone;

/** The current time zone setting
 @return The time zone name
 */
- (NSString *)tz UA_DEPRECATED(__LIB_1_2_2__);

/** Set a new time zone for the device
 @param tz NSString representing the new time zone name. If the name does not resolve to an actual NSTimeZone,
 the default time zone [NSTimeZone localTimeZone] is used
 */
- (void)setTz:(NSString *)tz UA_DEPRECATED(__LIB_1_2_2__);

///---------------------------------------------------------------------------------------
/// @name Alias
///---------------------------------------------------------------------------------------


/** Updates the alias on the device and on Urban Airship. Use only 
 when the alias is the only value that needs to be updated. 

 @param value Updated alias
 @warning *Warning* When updating several 
 server side values (tags, alias, time zone, quiettime) set the values first, then
 call the updateUA method. Batching these calls improves API and client perfomance.
 */
- (void)updateAlias:(NSString *)value UA_DEPRECATED(__LIB_1_2_2__);

///---------------------------------------------------------------------------------------
/// @name Quiet Time
///---------------------------------------------------------------------------------------


/** The current quiet time settings for this device
 @return NSMutableDictionary with the current quiet time settings
 */
- (NSDictionary*)quietTime;

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
 
  @param info An NSDictionary containing registraton keys and values. See
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
 @param info An NSDictionary containing registraton keys and values. See
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
