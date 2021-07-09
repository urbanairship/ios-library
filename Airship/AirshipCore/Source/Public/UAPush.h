/* Copyright Airship and Contributors */

#import "UAGlobal.h"
#import "UAirship.h"
#import "UANotificationContent.h"
#import "UANotificationResponse.h"
#import "UANotificationAction.h"
#import "UAComponent.h"

@class UANotificationCategory;

NS_ASSUME_NONNULL_BEGIN

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
 * Notification options
 */
typedef NS_OPTIONS(NSUInteger, UANotificationOptions) {
    UANotificationOptionNone = 0,
    UANotificationOptionBadge   = (1 << 0),
    UANotificationOptionSound   = (1 << 1),
    UANotificationOptionAlert   = (1 << 2),
    UANotificationOptionCarPlay = (1 << 3),
    UANotificationOptionCriticalAlert = (1 << 4),
    UANotificationOptionProvidesAppNotificationSettings = (1 << 5),
    UANotificationOptionProvisional = (1 << 6),
    UANotificationOptionAnnouncement = (1 << 7),
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
    UAAuthorizedNotificationSettingsAnnouncement = (1 << 7),
};

/**
 * Authorization status
 */
typedef NS_ENUM(NSInteger, UAAuthorizationStatus) {
    UAAuthorizationStatusNotDetermined = 0,
    UAAuthorizationStatusDenied,
    UAAuthorizationStatusAuthorized,
    UAAuthorizationStatusProvisional,
    UAAuthorizationStatusEphemeral,
};

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
 * @param options The notification presentation options.
 * @param notification The notification.
 * @return a UNNotificationPresentationOptions enum value indicating the presentation options for the notification.
 */
- (UNNotificationPresentationOptions)extendPresentationOptions:(UNNotificationPresentationOptions)options notification:(UNNotification *)notification;

@end


//---------------------------------------------------------------------------------------
// UAPush Class
//---------------------------------------------------------------------------------------

/**
 * This singleton provides an interface to the functionality provided by the Airship iOS Push API.
 */
@interface UAPush : UAComponent


///---------------------------------------------------------------------------------------
/// @name Push Notifications
///---------------------------------------------------------------------------------------

/**
 * Enables/disables background remote notifications on this device through Airship.
 * Defaults to `YES`.
 */
@property (nonatomic, assign) BOOL backgroundPushNotificationsEnabled;

/**
 * Sets the default value for backgroundPushNotificationsEnabled. The default is `YES`.
 * After the backgroundPushNotificationsEnabled value has been directly set, this
 * value has no effect.
 * @deprecated Deprecated - to be removed in SDK 15.0.
 */
@property (nonatomic, assign) BOOL backgroundPushNotificationsEnabledByDefault DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 15.0.");

/**
 * Enables/disables user notifications on this device through Airship.
 * Defaults to `NO`. Once set to `YES`, the user will be prompted for remote notifications.
 */
@property (nonatomic, assign) BOOL userPushNotificationsEnabled;

/**
 * Enables/disables sending the device token during channel registration. Flag will now just call through to Privacy Manager.
 *
 * @deprecated Deprecated – to be removed in SDK version 15.0. Please use the Privacy Manager.
 */
@property (nonatomic, assign) BOOL pushTokenRegistrationEnabled DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 15.0. Please use the Privacy Manager.");


/**
 * Sets the default value for userPushNotificationsEnabled. The default is `NO`.
 * After the userPushNotificationsEnabled value has been directly set, this value
 * has no effect.
 * @deprecated Deprecated - to be removed in SDK 15.0.
 */
@property (nonatomic, assign) BOOL userPushNotificationsEnabledByDefault DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 15.0.");

/**
 * Enables/disables extended App Clip user notifications on this device through Airship.
 * Defaults to `NO`. Once set to `YES`, the user will be prompted for remote notifications.
 * @warning This property should only be set in an App Clip context. In all other cases, setting it to any value will have no effect.
 * If userPushNotificationsEnabled is set to 'NO' , setting this property will have no effect.
 */
@property (nonatomic, assign) BOOL extendedPushNotificationPermissionEnabled;

/**
 * The device token for this device, as a hex string.
 */
@property (nonatomic, copy, readonly, nullable) NSString *deviceToken;

/**
 * User Notification options this app will request from APNS. Changes to this value
 * will not take effect until the next time the app registers with
 * updateRegistration.
 *
 * Defaults to alert, sound and badge.
 */
@property (nonatomic, assign) UANotificationOptions notificationOptions;

/**
 * Custom notification categories. Airship default notification
 * categories will be unaffected by this field.
 *
 * Changes to this value will not take effect until the next time the app registers
 * with updateRegistration.
 */
@property (nonatomic, copy) NSSet<UANotificationCategory *> *customCategories;

/**
 * The combined set of notification categories from `customCategories` set by the app
 * and the Airship provided categories.
 */
@property (nonatomic, readonly) NSSet<UANotificationCategory *> *combinedCategories;

/**
 * Sets authorization required for the default Airship categories. Only applies
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
 * If push is disabled in privacy manager, this value could be out of date.
 *
 * Note: this value reflects all the notification settings currently enabled in the
 * Settings app and does not take into account which options were originally requested.
 */
@property (nonatomic, readonly) UAAuthorizedNotificationSettings authorizedNotificationSettings;

/**
 * The current authorization status.
 * If push is disabled in privacy manager, this value could be out of date.
 */
@property (nonatomic, readonly) UAAuthorizationStatus authorizationStatus;

/**
 * Indicates whether the user has been prompted for notifications or not.
 * If push is disabled in privacy manager, this value will be out of date.
 */
@property (nonatomic, assign, readonly) BOOL userPromptedForNotifications;

/**
 * The default presentation options to use for foreground notifications.
 */
@property (nonatomic, assign) UNNotificationPresentationOptions defaultPresentationOptions;

/**
 * The current badge number used by the device and on the Airship server.
 *
 * @note This property must be accessed on the main thread.
 */
@property (nonatomic, assign) NSInteger badgeNumber;

/**
 * The set of Accengage notification categories.
 * @note For internal use only. :nodoc:
 */
@property (nonatomic, copy) NSSet<UANotificationCategory *> *accengageCategories;

///---------------------------------------------------------------------------------------
/// @name Autobadge
///---------------------------------------------------------------------------------------

/**
 * Toggle the Airship auto-badge feature. Defaults to `NO` If enabled, this will update the
 * badge number stored by Airship every time the app is started or foregrounded.
 */
@property (nonatomic, assign, getter=isAutobadgeEnabled) BOOL autobadgeEnabled;

/**
 * Sets the badge number on the device and on the Airship server.
 * 
 * @note This method must be called on the main thread.
 *
 * @param badgeNumber The new badge number
 */
- (void)setBadgeNumber:(NSInteger)badgeNumber;

/**
 * Resets the badge to zero (0) on both the device and on Airships servers. This is a
 * convenience method for `setBadgeNumber:0`.
 *
 * @note This method must be called on the main thread.
 */
- (void)resetBadge;

/**
 * Enables user notifications on this device through Airship.
 *
 * Note: The completion handler will return the success state of system push authorization as it is defined by the
 * user's response to the push authorization prompt. The completion handler success state does NOT represent the
 * state of the userPushNotificationsEnabled flag, which will be invariably set to YES after the completion of this call.
 *
 * @param completionHandler The completion handler with success flag representing the system authorization state.
 */
- (void)enableUserPushNotifications:(void(^)(BOOL success))completionHandler;

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
/// @name Registration
///---------------------------------------------------------------------------------------

/**
 * Registers or updates the current registration with an API call. If push notifications are
 * not enabled, this unregisters the device token.
 *
 * Add a `UARegistrationDelegate` to `UAPush` to receive success and failure callbacks.
 */
- (void)updateRegistration;

@end

NS_ASSUME_NONNULL_END
