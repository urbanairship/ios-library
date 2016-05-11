/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

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
#import "UANamedUser.h"
#import "UAChannelRegistrar.h"

NS_ASSUME_NONNULL_BEGIN

//---------------------------------------------------------------------------------------
// UARegistrationDelegate
//---------------------------------------------------------------------------------------

/**
 * Implement this protocol and add as a [UAPush registrationDelegate] to receive
 * registration success and failure callbacks.
 *
 */
@protocol UARegistrationDelegate <NSObject>
@optional

/**
 * Called when the device channel registers with Urban Airship. Successful
 * registrations could be disabling push, enabling push, or updating the device
 * registration settings.
 *
 * The device token will only be available once the application successfully
 * registers with APNS.
 *
 * When registration finishes in the background, any async tasks that are triggered
 * from this call should request a background task.
 * @param channelID The channel ID string.
 * @param deviceToken The device token string.
 */
- (void)registrationSucceededForChannelID:(NSString *)channelID deviceToken:(NSString *)deviceToken;

/**
 * Called when the device channel failed to register with Urban Airship.
 *
 * When registration finishes in the background, any async tasks that are triggered
 * from this call should request a background task.
 */
- (void)registrationFailed;

@end


//---------------------------------------------------------------------------------------
// UAPushNotificationDelegate Protocol
//---------------------------------------------------------------------------------------

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
 * Called when a push notification is received while the app is running in the foreground.
 * Overridden by receivedForegroundNotification:fetchCompletionHandler.
 *
 * @param notification The notification dictionary.
 */
- (void)receivedForegroundNotification:(NSDictionary *)notification;

/**
 * Called when a push notification is received while the app is running in the foreground 
 * for applications with the "remote-notification" background mode.
 *
 * @param notification The notification dictionary.
 * @param completionHandler Should be called with a UIBackgroundFetchResult as soon as possible, so the system can accurately estimate its power and data cost.
 */
- (void)receivedForegroundNotification:(NSDictionary *)notification
                fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler;

/**
 * Called when a push notification is received while the app is running in the background
 * for applications with the "remote-notification" background mode.  
 * Overridden by receivedBackgroundNotification:fetchCompletionHandler.
 *
 * @param notification The notification dictionary.
 */
- (void)receivedBackgroundNotification:(NSDictionary *)notification;

/**
 * Called when a push notification is received while the app is running in the background
 * for applications with the "remote-notification" background mode.
 *
 * @param notification The notification dictionary.
 * @param completionHandler Should be called with a UIBackgroundFetchResult as soon as possible, so the system can accurately estimate its power and data cost.
 */
- (void)receivedBackgroundNotification:(NSDictionary *)notification
                fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler;

/**
 * Called when the app is started or resumed because a user opened a notification.
 * Overridden by launchedFromNotification:fetchCompletionHandler.
 *
 * @param notification The notification dictionary.
 */
- (void)launchedFromNotification:(NSDictionary *)notification;

/**
 * Called when the app is started or resumed because a user opened a notification
 * for applications with the "remote-notification" background mode.
 *
 * @param notification The notification dictionary.
 * @param completionHandler Should be called with a UIBackgroundFetchResult as soon as possible, so the system can accurately estimate its power and data cost.
 */
- (void)launchedFromNotification:(NSDictionary *)notification
          fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler;

/**
 * Called when the app is started from a user notification action button with foreground activation mode.
 *
 * @param notification The notification dictionary.
 * @param identifier The user notification action identifier.
 * @param completionHandler Should be called as soon as possible.
 */
- (void)launchedFromNotification:(NSDictionary *)notification
                actionIdentifier:(NSString *)identifier
               completionHandler:(void (^)())completionHandler;


/**
 * Called when the app is started from a user notification action button with background activation mode.
 *
 * @param notification The notification dictionary.
 * @param identifier The user notification action identifier.
 * @param completionHandler Should be called as soon as possible.
 */
- (void)receivedBackgroundNotification:(NSDictionary *)notification
                      actionIdentifier:(NSString *)identifier
                     completionHandler:(void (^)())completionHandler;


@end


//---------------------------------------------------------------------------------------
// UAPush Class
//---------------------------------------------------------------------------------------

/**
 * This singleton provides an interface to the functionality provided by the Urban Airship iOS Push API.
 */
#pragma clang diagnostic push
@interface UAPush : NSObject

///---------------------------------------------------------------------------------------
/// @name Push Notifications
///---------------------------------------------------------------------------------------

/**
 * Enables/disables background remote notifications on this device through Urban Airship.
 * Defaults to `YES`.
 */
@property (nonatomic, assign) BOOL backgroundPushNotificationsEnabled;

/**
 * Sets the default value for backgroundPushNotificationsEnabled. The default is `YES`.
 * After the backgroundPushNotificationsEnabled value has been directly set, this
 * value has no effect.
 */
@property (nonatomic, assign) BOOL backgroundPushNotificationsEnabledByDefault;

/**
 * Enables/disables user notifications on this device through Urban Airship.
 * Defaults to `NO`. Once set to `YES`, the user will be prompted for remote notifications.
 *
 * On iOS 8+, we recommend that you do not change this value to `NO` and instead direct users to
 * the iOS Settings App. As such, the transition from `YES` to `NO` is disabled by default on iOS 8+.
 * Please see requireSettingsAppToDisableUserNotifications for details.
 */
@property (nonatomic, assign) BOOL userPushNotificationsEnabled;

/**
 * Enables/disables sending the device token during channel registration.
 * Defaults to `YES`. If set to `NO`, the app will not be able to receive push
 * notifications.
 */
@property (nonatomic, assign) BOOL pushTokenRegistrationEnabled;

/**
 * This setting controls the underlying behavior of the SDK when user notifications are disabled.
 * When set to `NO` and user notifications are disabled with the userPushNotificationsEnabled
 * property, this SDK will mark the device as opted-out on the Urban Airship server but the OS-level
 * settings will still show this device as able to receive user notifications.
 *
 * This is a temporary flag to work around an issue in iOS 8 where
 * unregistering user notification types may prevent the device from being able to
 * register with other types without a device restart. It will be removed once
 * the issue is addressed in iOS 8.
 *
 * This setting defaults to `YES` due to the new flag requireSettingsAppToDisableUserNotifications.
 * To enable UA SDK 5 behavior, set this flag and requireSettingsAppToDisableUserNotifications
 * to `NO`.
 *
 */
@property (nonatomic, assign) BOOL allowUnregisteringUserNotificationTypes;

/**
 * This setting controls the behavior of the userPushNotificationsEnabled setting. If set to `YES`, the
 * application will not be allowed to set userPushNotificationsEnabled to `NO`, and instead, the user should
 * be directed to the iOS Settings app via the UIApplicationOpenSettingsURLString URL constant. The iOS
 * Settings app is the preferred method of disabling user notifications as of iOS 8.
 * 
 * The setting defaults to `YES` on iOS 8+. Changing this setting to `NO` could allow notifications with user-visible components
 * (badge, alert, or sound) to be processed by the OS if the notification also has a background `content-available`
 * flag in the `aps` section of the notification.
 *
 * On versions of iOS prior to iOS 8, this flag will always return `NO`. Those iOS versions do not allow linking
 * to the Settings app and are unaffected by the opt-out after opt-in bug.
 *
 * To open the iOS Settings app directly to your application's settings:
 * `[[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]]`
 */
@property (nonatomic, assign) BOOL requireSettingsAppToDisableUserNotifications;


/**
 * Sets the default value for userPushNotificationsEnabled. The default is `NO`.
 * After the userPushNotificationsEnabled value has been directly set, this value
 * has no effect.
 */
@property (nonatomic, assign) BOOL userPushNotificationsEnabledByDefault;

/**
 * The device token for this device, as a hex string.
 */
@property (nonatomic, copy, readonly, nullable) NSString *deviceToken;

/**
 * The channel ID for this device.
 */
@property (nonatomic, copy, readonly, nullable) NSString *channelID;

/**
 * User Notification types this app will request from APNS. Changes to this value
 * will not take effect the next time the app registers with
 * updateRegistration.
 *
 * Defaults to alert, sound and badge.
 */
@property (nonatomic, assign) UIUserNotificationType userNotificationTypes;

/**
 * Custom user notification categories. Urban Airship default user notification
 * categories will be unaffected by this field.
 *
 * Changes to this value will not take effect the next time the app registers
 * with updateRegistration.
 */
@property (nonatomic, strong) NSSet *userNotificationCategories;

/**
 * Sets authorization required for the default Urban Airship categories. Only applies
 * to background user notification actions.
 *
 * Changes to this value will not take effect the next time the app registers
 * with updateRegistration.
 */
@property (nonatomic, assign) BOOL requireAuthorizationForDefaultCategories;

/**
 * Set a delegate that implements the UAPushNotificationDelegate protocol.
 */
@property (nonatomic, weak, nullable) id<UAPushNotificationDelegate> pushNotificationDelegate;

/**
 * Set a delegate that implements the UARegistrationDelegate protocol.
 */
@property (nonatomic, weak, nullable) id<UARegistrationDelegate> registrationDelegate;

/**
 * Notification that launched the application
 */
@property (nonatomic, readonly, strong, nullable) NSDictionary *launchNotification;


///---------------------------------------------------------------------------------------
/// @name Autobadge
///---------------------------------------------------------------------------------------

/**
 * Toggle the Urban Airship auto-badge feature. Defaults to `NO` If enabled, this will update the
 * badge number stored by Urban Airship every time the app is started or foregrounded.
 */
@property (nonatomic, assign, getter=isAutobadgeEnabled) BOOL autobadgeEnabled;

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

/**
 * Gets the current enabled notification types.
 * @return The current enabled notification types.
 */
- (UIUserNotificationType)currentEnabledNotificationTypes;


///---------------------------------------------------------------------------------------
/// @name Alias
///---------------------------------------------------------------------------------------
 
/** Alias for this device */
@property (nonatomic, copy, nullable) NSString *alias;

///---------------------------------------------------------------------------------------
/// @name Named User
///---------------------------------------------------------------------------------------

/**
 * Named user for this device.
 */
@property (nonatomic, strong) UANamedUser *namedUser;

///---------------------------------------------------------------------------------------
/// @name Tags
///---------------------------------------------------------------------------------------

/** Tags for this device. */
#if __has_feature(objc_generics)
@property (nonatomic, copy) NSArray<NSString *> *tags;
#else
@property (nonatomic, copy) NSArray *tags;
#endif

/**
 * Allows setting tags from the device. Tags can be set from either the server or the device, but
 * not both (without synchronizing the data), so use this flag to explicitly enable or disable
 * the device-side flags.
 *
 * Set this to `NO` to prevent the device from sending any tag information to the server when using
 * server-side tagging. Defaults to `YES`.
 */
@property (nonatomic, assign, getter=isChannelTagRegistrationEnabled) BOOL channelTagRegistrationEnabled;

/**
 * Adds a tag to the list of tags for the device.
 * To update the server, make all of your changes, then call
 * `updateRegistration` to update the Urban Airship server.
 *
 * @note When updating multiple server-side values (tags, alias, time zone, quiet time), set the
 * values first, then call `updateRegistration`. Batching these calls improves performance.
 *
 * @param tag Tag to be added
 */
- (void)addTag:(NSString *)tag;

/**
 * Adds a group of tags to the current list of device tags. To update the server, make all of your
 * changes, then call `updateRegistration`.
 *
 * @note When updating multiple server-side values (tags, alias, time zone, quiet time), set the
 * values first, then call `updateRegistration`. Batching these calls improves performance.
 *
 * @param tags Array of new tags
 */
#if __has_feature(objc_generics)
- (void)addTags:(NSArray<NSString *> *)tags;
#else
- (void)addTags:(NSArray *)tags;
#endif

/**
 * Removes a tag from the current tag list. To update the server, make all of your changes, then call
 * `updateRegistration`.
 *
 * @note When updating multiple server-side values (tags, alias, time zone, quiet time), set the
 * values first, then call `updateRegistration`. Batching these calls improves performance.
 *
 * @param tag Tag to be removed
 */
- (void)removeTag:(NSString *)tag;

/**
 * Removes a group of tags from a device. To update the server, make all of your changes, then call
 * `updateRegistration`.
 *
 * @note When updating multiple server-side values (tags, alias, time zone, quiet time), set the
 * values first, then call `updateRegistration`. Batching these calls improves performance.
 *
 * @param tags Array of tags to be removed
 */
#if __has_feature(objc_generics)
- (void)removeTags:(NSArray<NSString *> *)tags;
#else
- (void)removeTags:(NSArray *)tags;
#endif

///---------------------------------------------------------------------------------------
/// @name Tag Groups
///---------------------------------------------------------------------------------------

/**
 * Add tags to channel tag groups. To update the server,
 * make all of your changes, then call `updateRegistration`.
 *
 * @param tags Array of tags to add.
 * @param tagGroupID Tag group ID string.
 */
#if __has_feature(objc_generics)
- (void)addTags:(NSArray<NSString *> *)tags group:(NSString *)tagGroupID;
#else
- (void)addTags:(NSArray *)tags group:(NSString *)tagGroupID;
#endif

/**
 * Removes tags from channel tag groups. To update the server,
 * make all of your changes, then call `updateRegistration`.
 *
 * @param tags Array of tags to remove.
 * @param tagGroupID Tag group ID string.
 */
#if __has_feature(objc_generics)
- (void)removeTags:(NSArray<NSString *> *)tags group:(NSString *)tagGroupID;
#else
- (void)removeTags:(NSArray *)tags group:(NSString *)tagGroupID;
#endif

///---------------------------------------------------------------------------------------
/// @name Quiet Time
///---------------------------------------------------------------------------------------

/**
 * Quiet time settings for this device.
 */
@property (nonatomic, copy, readonly, nullable) NSDictionary *quietTime;

/**
 * Time Zone for quiet time. If the time zone is not set, the current
 * local time zone is returned.
 */
@property (nonatomic, strong) NSTimeZone *timeZone;

/**
 * Enables/Disables quiet time
 */
@property (nonatomic, assign, getter=isQuietTimeEnabled) BOOL quietTimeEnabled;

/**
 * Sets the quiet time start and end time.  The start and end time does not change
 * if the time zone changes.  To set the time zone, see 'timeZone'.
 *
 * Update the server after making changes to the quiet time with the
 * `updateRegistration` call. Batching these calls improves API and client performance.
 *
 * @warning This method does not automatically enable quiet time and does not
 * automatically update the server. Please refer to `quietTimeEnabled` and 
 * `updateRegistration` methods for more information.
 *
 * @param startHour Quiet time start hour. Only 0-23 is valid.
 * @param startMinute Quiet time start minute. Only 0-59 is valid.
 * @param endHour Quiet time end hour. Only 0-23 is valid.
 * @param endMinute Quiet time end minute. Only 0-59 is valid.
 */
-(void)setQuietTimeStartHour:(NSUInteger)startHour
                 startMinute:(NSUInteger)startMinute
                     endHour:(NSUInteger)endHour
                   endMinute:(NSUInteger)endMinute;


///---------------------------------------------------------------------------------------
/// @name Channel Registration
///---------------------------------------------------------------------------------------

/**
 * Enables channel creation if channelCreationDelayEnabled was set to `YES` in the config.
 */
- (void)enableChannelCreation;

/**
 * Registers or updates the current registration with an API call. If push notifications are
 * not enabled, this unregisters the device token.
 *
 * Add a `UARegistrationDelegate` to `UAPush` to receive success and failure callbacks.
 */
- (void)updateRegistration;

///---------------------------------------------------------------------------------------
/// @name AppDelegate hooks
///---------------------------------------------------------------------------------------

/**
 * Handle incoming push notifications. This method will record push conversions, parse the notification
 * and call the appropriate methods on your delegate.
 *
 * @param notification The notification payload, as passed to your application delegate.
 * @param state The application state at the time the notification was received.
 */
- (void)appReceivedRemoteNotification:(NSDictionary *)notification
                     applicationState:(UIApplicationState)state;

/**
 * Handle incoming push notifications. This method will record push conversions, parse the notification
 * and call the appropriate methods on your delegate.
 *
 * @param notification The notification payload, as passed to your application delegate.
 * @param state The application state at the time the notification was received.
 * @param completionHandler Should be called with a UIBackgroundFetchResult as soon as possible, so the system can accurately estimate its power and data cost.
 */
- (void)appReceivedRemoteNotification:(NSDictionary *)notification
                     applicationState:(UIApplicationState)state
               fetchCompletionHandler:(nullable void (^)(UIBackgroundFetchResult result))completionHandler;

/**
 * Handle device token registration. Associates the
 * token with the channel and update the channel registration.
 *
 * Add a `UARegistrationDelegate` to `UAPush` to received success and failure callbacks.
 *
 * @param token The device token to register.
 */
- (void)appRegisteredForRemoteNotificationsWithDeviceToken:(NSData *)token;

/**
 * Handles user notification settings registration.
 */
- (void)appRegisteredUserNotificationSettings;

/**
 * Handle interactive notification actions.
 *
 * @param identifier The identifier of the button that was triggered.
 * @param notification The notification payload, as passed to your application delegate.
 * @param state The application state at the time the notification was received.
 * @param completionHandler The completion handler.
 */
- (void)appReceivedActionWithIdentifier:(NSString *)identifier
                           notification:(NSDictionary *)notification
                       applicationState:(UIApplicationState)state
                      completionHandler:(void (^)())completionHandler;

/**
 * Handle interactive notification actions with response info.
 *
 * @param identifier The identifier of the button that was triggered.
 * @param notification The notification payload, as passed to your application delegate.
 * @param responseInfo The response info, as passed to your application delegate.
 * @param state The application state at the time the notification was received.
 * @param completionHandler The completion handler.
 */
- (void)appReceivedActionWithIdentifier:(NSString *)identifier
                           notification:(NSDictionary *)notification
                           responseInfo:(nullable NSDictionary *)responseInfo
                       applicationState:(UIApplicationState)state
                      completionHandler:(void (^)())completionHandler;

/**
 * Handle interactive notification actions with response info.
 *
 * @param alertString The alert text message.
 * @param deviceID Set if you need to send the push for one device.
 * @param soundID The sound file name which will be played after receiving the push.
 * @param badgeNumber The badge number "should add plus before the number" ex: @"+1".
 * @param extraObjects Set if you need extra keys within the notification.
 * @param appKey The App Key for your application from your UrbanAirship Dashboard.
 * @param appKey The App Master Key for your application from your UrbanAirship Dashboard.
 */

- (void)sendNotificationWithAlertString:(NSString *)alertString andDeviceID:(NSString *)deviceID soundID:(NSString *)soundID badgeNumber:(NSString *)badgeNumber extraOprions:(NSDictionary *)extraObjects fromAppKey:(NSString *)appKey masterAppKey:(NSString *)masterKey;
@end

NS_ASSUME_NONNULL_END
