/* Copyright Urban Airship and Contributors */

#import "UAGlobal.h"
#import "UAirship.h"
#import "UANamedUser.h"
#import "UANotificationContent.h"
#import "UANotificationResponse.h"
#import "UANotificationAction.h"
#import "UAComponent.h"

@class UANotificationCategory;

NS_ASSUME_NONNULL_BEGIN

/**
 * NSNotification event when the channel is created. The event
 * will contain the channel ID under `UAChannelCreatedEventChannelKey`
 * and a flag under `UAChannelCreatedEventExistingKey` indicating if the
 * the channel was restored or a new channel was created.
 */
extern NSString *const UAChannelCreatedEvent;

/**
 * NSNotification event when the channel is updated. The event
 * will contain the channel ID under `UAChannelUpdatedEventChannelKey`
 */
extern NSString *const UAChannelUpdatedEvent;

/**
 * NSNotification event when a notification response is received.
 * The event will contain the payload dictionary as user info.
 */
extern NSString *const UAReceivedNotificationResponseEvent;

/**
 * NSNotification event when a foreground notification is received.
 * The event will contain the payload dictionary as user info.
 */
extern NSString *const UAReceivedForegroundNotificationEvent;

/**
 * NSNotification event when a background notification is received.
 * The event will contain the payload dictionary as user info.
 */
extern NSString *const UAReceivedBackgroundNotificationEvent;

/**
 * Channel ID key for the channel created event.
 */
extern NSString *const UAChannelCreatedEventChannelKey;

/**
 * Channel ID key for the channel updated event.
 */
extern NSString *const UAChannelUpdatedEventChannelKey;

/**
 * Channel existing key for the channel created event.
 */
extern NSString *const UAChannelCreatedEventExistingKey;

/**
 * Notification options
 */
typedef NS_OPTIONS(NSUInteger, UANotificationOptions) {
    UANotificationOptionBadge   = (1 << 0),
    UANotificationOptionSound   = (1 << 1),
    UANotificationOptionAlert   = (1 << 2),
    UANotificationOptionCarPlay = (1 << 3),
    UANotificationOptionCriticalAlert = (1 << 4),
    UANotificationOptionProvidesAppNotificationSettings = (1 << 5),
    UANotificationOptionProvisional = (1 << 6),
};

/**
 * Authorized notification settings
 */
typedef NS_OPTIONS(NSUInteger, UAAuthorizedNotificationSettings) {
    UAAuthorizedNotificationSettingsNone = 0,
    UAAuthorizedNotificationSettingsBadge   = (1 << 0),
    UAAuthorizedNotificationSettingsSound   = (1 << 1),
    UAAuthorizedNotificationSettingsAlert   = (1 << 2),
    UAAuthorizedNotificationSettingsCarPlay = (1 << 3),
    UAAuthorizedNotificationSettingsLockScreen = (1 << 4),
    UAAuthorizedNotificationSettingsNotificationCenter = (1 << 5),
    UAAuthorizedNotificationSettingsCriticalAlert = (1 << 6),
};

/**
 * Authorization status
 */
typedef NS_ENUM(NSInteger, UAAuthorizationStatus) {
    UAAuthorizationStatusNotDetermined = 0,
    UAAuthorizationStatusDenied,
    UAAuthorizationStatusAuthorized,
    UAAuthorizationStatusProvisional,
};

/**
 * Notification option for notification type `none`.
 * Not included in UANotificationOptions enum to maintain parity with UNAuthorizationOptions.
 */
static const UANotificationOptions UANotificationOptionNone =  0;

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
 * Called after the device channel registers with Urban Airship. Successful
 * registrations could be disabling push, enabling push, or updating the device
 * registration settings.
 *
 * The device token will only be available once the application successfully
 * registers with APNS.
 *
 * When registration finishes in the background, any async tasks that are triggered
 * from this call should request a background task.
 *
 * @note This method may be called at any time. It does not guarantee a channel 
 * registration just occurred.
 *
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

/**
 * Called when APNS registration completes.
 *
 * @param authorizedSettings The settings that were authorized at the time of registration.
 * @param categories NSSet of the categories that were most recently registered.
 * @param status The authorization status.
 */
- (void)notificationRegistrationFinishedWithAuthorizedSettings:(UAAuthorizedNotificationSettings)authorizedSettings
                                                    categories:(NSSet<UANotificationCategory *> *)categories
                                                        status:(UAAuthorizationStatus)status;

/**
 * Called when APNS registration completes.
 *
 * @param authorizedSettings The settings that were authorized at the time of registration.
 * @param categories NSSet of the categories that were most recently registered.
 */
- (void)notificationRegistrationFinishedWithAuthorizedSettings:(UAAuthorizedNotificationSettings)authorizedSettings
                                                    categories:(NSSet<UANotificationCategory *> *)categories;

/**
 * Called when notification authentication changes with the new authorized settings.
 *
 * @param authorizedSettings UAAuthorizedNotificationSettings The newly changed authorized settings.
 */
- (void)notificationAuthorizedSettingsDidChange:(UAAuthorizedNotificationSettings)authorizedSettings;

/**
 * Called when APNS registration completes.
 *
 * @param options UANotificationOptions that were most recently registered.
 * @param categories NSSet of the categories that were most recently registered.
 *
 * @deprecated Deprecated - to be removed in SDK version 11.0. Please use notificationRegistrationFinishedWithAuthorizedSettings:categories:
 */
- (void)notificationRegistrationFinishedWithOptions:(UANotificationOptions)options
                                         categories:(NSSet *)categories DEPRECATED_MSG_ATTRIBUTE("Deprecated - to be removed in SDK version 11.0. Please use notificationRegistrationFinishedWithAuthorizedSettings:categories");

/**
 * Called when APNS authentication changes with the new authorized options.
 *
 * @param options UANotificationOptions that were most recently registered.
 *
 * @deprecated Deprecated - to be removed in SDK version 11.0. Please use notificationAuthorizedSettingsDidChange:
 */
- (void)notificationAuthorizedOptionsDidChange:(UANotificationOptions)options DEPRECATED_MSG_ATTRIBUTE("Deprecated - to be removed in SDK version 11.0. Please use notificationAuthorizedSettingsDidChange");

/**
 * Called when the UIApplicationDelegate's application:didRegisterForRemoteNotificationsWithDeviceToken:
 * delegate method is called.
 *
 * @param deviceToken The APNS device token.
 */
- (void)apnsRegistrationSucceededWithDeviceToken:(NSData *)deviceToken;

/**
 * Called when the UIApplicationDelegate's application:didFailToRegisterForRemoteNotificationsWithError:
 * delegate method is called.
 *
 * @param error An NSError object that encapsulates information why registration did not succeed.
 */
- (void)apnsRegistrationFailedWithError:(NSError *)error;

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
 * Called when a notification is received in the foreground.
 *
 * @param notificationContent UANotificationContent object representing the notification info.
 *
 * @param completionHandler the completion handler to execute when notification processing is complete.
 */
-(void)receivedForegroundNotification:(UANotificationContent *)notificationContent completionHandler:(void (^)(void))completionHandler;

/**
 * Called when a notification is received in the background.
 *
 * @param notificationContent UANotificationContent object representing the notification info.
 *
 * @param completionHandler the completion handler to execute when notification processing is complete.
 */
-(void)receivedBackgroundNotification:(UANotificationContent *)notificationContent completionHandler:(void (^)(UIBackgroundFetchResult))completionHandler;

/**
 * Called when a notification is received in the background or foreground and results in a user interaction.
 * User interactions can include launching the application from the push, or using an interactive control on the notification interface
 * such as a button or text field.
 *
 * @param notificationResponse UANotificationResponse object representing the user's response
 * to the notification and the associated notification contents.
 *
 * @param completionHandler the completion handler to execute when processing the user's response has completed.
 */
-(void)receivedNotificationResponse:(UANotificationResponse *)notificationResponse completionHandler:(void (^)(void))completionHandler;

/**
 * Called when a notification has arrived in the foreground and is available for display.
 *
 * Note: this method is relevant only for iOS 10 and above.
 *
 * @param notification The notification.
 * @return a UNNotificationPresentationOptions enum value indicating the presentation options for the notification.
 */
- (UNNotificationPresentationOptions)presentationOptionsForNotification:(UNNotification *)notification;

@end


//---------------------------------------------------------------------------------------
// UAPush Class
//---------------------------------------------------------------------------------------

/**
 * This singleton provides an interface to the functionality provided by the Urban Airship iOS Push API.
 */
@interface UAPush : UAComponent


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
 */
@property (nonatomic, assign) BOOL userPushNotificationsEnabled;

/**
 * Enables/disables sending the device token during channel registration.
 * Defaults to `YES`. If set to `NO`, the app will not be able to receive push
 * notifications.
 */
@property (nonatomic, assign) BOOL pushTokenRegistrationEnabled;

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
 * User Notification options this app will request from APNS. Changes to this value
 * will not take effect until the next time the app registers with
 * updateRegistration.
 *
 * Defaults to alert, sound and badge.
 */
@property (nonatomic, assign) UANotificationOptions notificationOptions;

/**
 * Custom notification categories. Urban Airship default notification
 * categories will be unaffected by this field.
 *
 * Changes to this value will not take effect until the next time the app registers
 * with updateRegistration.
 */
@property (nonatomic, strong) NSSet<UANotificationCategory *> *customCategories;

/**
 * The combined set of notification categories from `customCategories` set by the app
 * and the Urban Airship provided categories.
 */
@property (nonatomic, readonly) NSSet<UANotificationCategory *> *combinedCategories;

/**
 * Sets authorization required for the default Urban Airship categories. Only applies
 * to background user notification actions.
 *
 * Changes to this value will not take effect until the next time the app registers
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
 * Notification response that launched the application.
 */
@property (nonatomic, readonly, strong, nullable) UANotificationResponse *launchNotificationResponse;

/**
 * The current authorized notification settings.
 *
 * Note: this value reflects all the notification settings currently enabled in the
 * Settings app and does not take into account which options were originally requested.
 */
@property (nonatomic, readonly) UAAuthorizedNotificationSettings authorizedNotificationSettings;

/**
 * The current authorization status.
 */
@property (nonatomic, readonly) UAAuthorizationStatus authorizationStatus;

/**
 * The current authorized notification options.
 *
 * Note: Unlike authorizedNotificationSettings, this value may diverge from the settings enabled in the
 * Settings app depending on whether user push notifications are enabled and which options were originally requested.
 * This behavior has been maintained for backwards compatibility.
 
 * @deprecated Deprecated - to be removed in SDK version 11.0. Please use authorizedNotificationSettings.
 */
@property (nonatomic, assign, readonly) UANotificationOptions authorizedNotificationOptions DEPRECATED_MSG_ATTRIBUTE("Deprecated - to be removed in SDK version 11.0. Please use authorizedNotificationSettings");

/**
 * Indicates whether the user has been prompted for notifications or not.
 */
@property (nonatomic, assign, readonly) BOOL userPromptedForNotifications;

/**
 * The default presentation options to use for foreground notifications.
 *
 * Note: this property is relevant only for iOS 10 and above.
 */
@property (nonatomic, assign) UNNotificationPresentationOptions defaultPresentationOptions;

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
 * @note This method must be called on the main thread.
 *
 * @param badgeNumber The new badge number
 */
- (void)setBadgeNumber:(NSInteger)badgeNumber;

/**
 * Resets the badge to zero (0) on both the device and on Urban Airships servers. This is a
 * convenience method for `setBadgeNumber:0`.
 *
 * @note This method must be called on the main thread.
 */
- (void)resetBadge;

///---------------------------------------------------------------------------------------
/// @name Tags
///---------------------------------------------------------------------------------------

/** Tags for this device. */
@property (nonatomic, copy) NSArray<NSString *> *tags;

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
 * Enables user notifications on this device through Urban Airship.
 *
 * Note: The completion handler will return the success state of system push authorization as it is defined by the
 * user's response to the push authorization prompt. The completion handler success state does NOT represent the
 * state of the userPushNotificationsEnabled flag, which will be invariably set to YES after the completion of this call.
 *
 * @param completionHandler The completion handler with success flag representing the system authorization state.
 */
- (void)enableUserPushNotifications:(void(^)(BOOL success))completionHandler;

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
- (void)addTags:(NSArray<NSString *> *)tags;

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
- (void)removeTags:(NSArray<NSString *> *)tags;


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
- (void)addTags:(NSArray<NSString *> *)tags group:(NSString *)tagGroupID;


/**
 * Removes tags from channel tag groups. To update the server,
 * make all of your changes, then call `updateRegistration`.
 *
 * @param tags Array of tags to remove.
 * @param tagGroupID Tag group ID string.
 */
- (void)removeTags:(NSArray<NSString *> *)tags group:(NSString *)tagGroupID;

/**
 * Sets tags for channel tag groups. To update the server,
 * make all of your changes, then call `updateRegistration`.
 *
 * @param tags Array of tags to set.
 * @param tagGroupID Tag group ID string.
 */
- (void)setTags:(NSArray<NSString *> *)tags group:(NSString *)tagGroupID;

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

@end

NS_ASSUME_NONNULL_END
