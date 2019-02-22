/* Copyright Urban Airship and Contributors */

#import "UAPush.h"
#import "UAirship.h"
#import "UAChannelRegistrar+Internal.h"
#import "UAAPNSRegistrationProtocol+Internal.h"
#import "UAAPNSRegistration+Internal.h"
#import "UAComponent+Internal.h"

@class UAPreferenceDataStore;
@class UAConfig;
@class UATagGroupsAPIClient;
@class UATagGroupsRegistrar;

NS_ASSUME_NONNULL_BEGIN

/**
 * User push notification enabled data store key.
 */
extern NSString *const UAUserPushNotificationsEnabledKey;

/**
 * Background push notification enabled data store key.
 */
extern NSString *const UABackgroundPushNotificationsEnabledKey;

/**
 * Device token sent during channel registration enabled data store key.
 */
extern NSString *const UAPushTokenRegistrationEnabledKey;

/**
 * Alias data store key.
 */
extern NSString *const UAPushAliasSettingsKey;

/**
 * Tags data store key.
 */
extern NSString *const UAPushTagsSettingsKey;

/**
 * Badge data store key.
 */
extern NSString *const UAPushBadgeSettingsKey;

/**
 * Quiet time settings data store key.
 */
extern NSString *const UAPushQuietTimeSettingsKey;

/**
 * Quiet enabled data store key.
 */
extern NSString *const UAPushQuietTimeEnabledSettingsKey;

/**
 * Quiet time time zone data store key.
 */
extern NSString *const UAPushTimeZoneSettingsKey;

/**
 * Quiet time settings start key.
 */
extern NSString *const UAPushQuietTimeStartKey;

/**
 * Quiet time settings end key.
 */
extern NSString *const UAPushQuietTimeEndKey;

/**
 * If channel creation should occur on foreground data store key.
 */
extern NSString *const UAPushChannelCreationOnForeground;

/**
 * If push enabled settings have been migrated data store key.
 */
extern NSString *const UAPushEnabledSettingsMigratedKey;

/**
 * Channel ID data store key.
 */
extern NSString *const UAPushChannelIDKey;

/**
 * Channel location data store key.
 */
extern NSString *const UAPushChannelLocationKey;

/**
 * Old push enabled key.
 */
extern NSString *const UAPushEnabledKey;

@interface UAPush () <UAChannelRegistrarDelegate, UAAPNSRegistrationDelegate>

///---------------------------------------------------------------------------------------
/// @name Push Internal Properties
///---------------------------------------------------------------------------------------

/**
 * Device token as a string.
 */
@property (nonatomic, copy, nullable) NSString *deviceToken;

/**
 * Allows disabling channel registration before a channel is created.  Channel registration will resume
 * when this flag is set to `YES`.
 *
 * Set this to `NO` to disable channel registration. Defaults to `YES`.
 */
@property (nonatomic, assign, getter=isChannelCreationEnabled) BOOL channelCreationEnabled;

/**
 * The UAChannelRegistrar that handles registering the device with Urban Airship.
 */
@property (nonatomic, strong) UAChannelRegistrar *channelRegistrar;

/**
 * Notification that launched the application.
 */
@property (nullable, nonatomic, strong) UANotificationResponse *launchNotificationResponse;

/**
 * Indicates whether APNS registration is out of date or not.
 */
@property (nonatomic, assign) BOOL shouldUpdateAPNSRegistration;

/**
 * The preference data store.
 */
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;

/**
 * The current authorized notification settings.
 *
 * Note: this value reflects all the notification settings currently enabled in the
 * Settings app and does not take into account which options were originally requested.
 */
@property (nonatomic, assign) UAAuthorizedNotificationSettings authorizedNotificationSettings;

/**
 * The current authorization status.
 */
@property (nonatomic, assign) UAAuthorizationStatus authorizationStatus;

/**
 * Indicates whether the user has been prompted for notifications or not.
 */
@property (nonatomic, assign) BOOL userPromptedForNotifications;

/**
 * The push registration instance.
 */
@property (nonatomic, strong) id<UAAPNSRegistrationProtocol> pushRegistration;

/**
 * Flag indicating app is running in the foreground
 */
@property (nonatomic, assign) BOOL isForegrounded;

///---------------------------------------------------------------------------------------
/// @name Push Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method to create a push instance.
 * @param config The Urban Airship config
 * @param dataStore The preference data store.
 * @param tagGroupsregistrar The tag groups registrar.
 * @return A new push instance.
 */
+ (instancetype)pushWithConfig:(UAConfig *)config
                     dataStore:(UAPreferenceDataStore *)dataStore
            tagGroupsRegistrar:(UATagGroupsRegistrar *)tagGroupsregistrar;


/**
 * Factory method to create a push instance. For testing
 * @param config The Urban Airship config
 * @param dataStore The preference data store.
 * @param tagGroupsregistrar The tag groups registrar.
 * @param notificationCenter The notification center.
 * @param pushRegistration The push registration instance.
 * @param application The application.
 * @param dispatcher The dispatcher.
 * @return A new push instance.
 */
+ (instancetype)pushWithConfig:(UAConfig *)config
                     dataStore:(UAPreferenceDataStore *)dataStore
            tagGroupsRegistrar:(UATagGroupsRegistrar *)tagGroupsregistrar
            notificationCenter:(NSNotificationCenter *)notificationCenter
              pushRegistration:(id<UAAPNSRegistrationProtocol>)pushRegistration
                   application:(UIApplication *)application
                    dispatcher:(UADispatcher *)dispatcher;

/**
 * Get the local time zone, considered the default.
 * @return The local time zone.
 */
- (NSTimeZone *)defaultTimeZoneForQuietTime;

/**
 * Called on active NSNotificationCenter notifications (on "active" rather than "foreground" so that we
 * can capture the push ID sent with a converting push). Triggers an updateRegistration.
 */
- (void)applicationDidBecomeActive;

/**
 * Used to clear a flag set on foreground to prevent double registration on
 * app init.
 */
- (void)applicationDidEnterBackground;

#if !TARGET_OS_TV    // UIBackgroundRefreshStatusAvailable not available on tvOS
/**
 * Used to update channel registration when the background refresh status changes.
 */
- (void)applicationBackgroundRefreshStatusChanged;
#endif

/**
 * Called when the channel registrar creates a new channel.
 * @param channelID The channel ID string.
 * @param channelLocation The channel location string.
 * @param existing Boolean to indicate if the channel previously existed or not.
 */
- (void)channelCreated:(NSString *)channelID
       channelLocation:(NSString *)channelLocation
              existing:(BOOL)existing;

/**
 * Creates a UAChannelRegistrationPayload.
 *
 * @param completionHandler A completion handler that will be called with the created UAChannelRegistrationPayload payload.
 */
- (void)createChannelPayload:(void (^)(UAChannelRegistrationPayload *))completionHandler;

/**
 * Registers or updates the current registration with an API call. If push notifications are
 * not enabled, this unregisters the device token.
 *
 * Add a `UARegistrationDelegate` to `UAPush` to receive success and failure callbacks.
 *
 * @param forcefully Tells the device api client to do any device api call forcefully.
 */
- (void)updateChannelRegistrationForcefully:(BOOL)forcefully;

/**
 * Returns YES if background push is enabled and configured for the device. Used
 * as the channel's 'background' flag.
 */
- (BOOL)backgroundPushNotificationsAllowed;

/**
 * Returns YES if user notifications are configured and enabled for the device. Used
 * as the channel's 'opt_in' flag.
 */
- (BOOL)userPushNotificationsAllowed;

/**
 * Migrates the old pushEnabled setting to the new userPushNotificationsEnabled
 * setting.
 */
- (void)migratePushSettings;

/**
 * Updates the registration with APNS. Call after modifying notification types
 * and user notification categories.
 */
- (void)updateAPNSRegistration;

/**
 * Updates the authorized notification types.
 */
- (void)updateAuthorizedNotificationTypes;

/**
 * Called to return the presentation options for an iOS 10 notification.
 *
 * @param notification The notification.
 * @return Foreground presentation options.
 */
- (UNNotificationPresentationOptions)presentationOptionsForNotification:(UNNotification *)notification;

/**
 * Called when a notification response is received.
 * 
 * @param response The notification response.
 * @param handler The completion handler.
 */
- (void)handleNotificationResponse:(UANotificationResponse *)response completionHandler:(void (^)(void))handler;

/**
 * Called when a remote notification is received.
 *
 * @param notification The notification content.
 * @param foreground If the notification was recieved in the foreground or not.
 * @param handler The completion handler.
 */
- (void)handleRemoteNotification:(UANotificationContent *)notification foreground:(BOOL)foreground completionHandler:(void (^)(UIBackgroundFetchResult))handler;

/**
 * Called by the UIApplicationDelegate's application:didRegisterForRemoteNotificationsWithDeviceToken:
 * so UAPush can forward the delegate call to its registration delegate.
 *
 * @param application The application instance.
 * @param deviceToken The APNS device token.
 */
- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken;

/**
 * Called by the UIApplicationDelegate's application:didFailToRegisterForRemoteNotificationsWithError:
 * so UAPush can forward the delegate call to its registration delegate.
 *
 * @param application The application instance.
 * @param error An NSError object that encapsulates information why registration did not succeed.
 */
- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error;

/**
 * Called to update the tag groups for the current channel.
 */
- (void)updateChannelTagGroups;

/**
 * Removes the existing channel and causes the registrar to create a new channel on next registration.
 */
- (void)resetChannel;

@end

NS_ASSUME_NONNULL_END
