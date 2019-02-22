/* Copyright Urban Airship and Contributors */

#import "UAirship.h"

@class UABaseAppDelegateSurrogate;
@class UAJavaScriptDelegate;
@class UAPreferenceDataStore;
@class UAChannelCapture;
@class UAInAppMessageManager;
@class UARemoteConfigManager;

@interface UAirship()

NS_ASSUME_NONNULL_BEGIN

///---------------------------------------------------------------------------------------
/// @name Airship Internal Properties
///---------------------------------------------------------------------------------------

// Setters for public readonly-getters
@property (nonatomic, strong) UAConfig *config;
@property (nonatomic, strong) UAActionRegistry *actionRegistry;
@property (nonatomic, assign) BOOL remoteNotificationBackgroundModeEnabled;
@property (nonatomic, strong, nullable) id<UAJavaScriptDelegate> actionJSDelegate;
@property (nonatomic, strong) UAApplicationMetrics *applicationMetrics;
@property (nonatomic, strong) UAWhitelist *whitelist;
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) UAChannelCapture *channelCapture;

/**
 * The push manager.
 */
@property (nonatomic, strong) UAPush *sharedPush;

#if !TARGET_OS_TV
/**
 * The inbox user.
 */
@property (nonatomic, strong) UAUser *sharedInboxUser;

/**
 * The inbox.
 */
@property (nonatomic, strong) UAInbox *sharedInbox;

/**
 * The legacy in-app messaging manager.
 */
@property (nonatomic, strong) UALegacyInAppMessaging *sharedLegacyInAppMessaging;

/**
 * The in-app messaging manager.
 */
@property (nonatomic, strong) UAInAppMessageManager *sharedInAppMessageManager;

/**
 * The default message center.
 */
@property (nonatomic, strong) UAMessageCenter *sharedMessageCenter;
#endif

/**
 * The location manager.
 */
@property (nonatomic, strong) UALocation *sharedLocation;

/**
 * The named user.
 */
@property (nonatomic, strong) UANamedUser *sharedNamedUser;


/**
 * Shared automation manager.
 */
@property (nonatomic, strong) UAAutomation *sharedAutomation;

/**
 * The shared analytics manager.
 */
@property (nonatomic, strong) UAAnalytics *sharedAnalytics;

/**
 * Shared remoteDataManager.
 */
@property (nonatomic, strong) UARemoteDataManager *sharedRemoteDataManager;

/**
 * Shared remoteConfigManager.
 */
@property (nonatomic, strong) UARemoteConfigManager *sharedRemoteConfigManager;

/**
 * Returns the `UARemoteDataManager` instance.
 */
+ (null_unspecified UARemoteDataManager *)remoteDataManager;

///---------------------------------------------------------------------------------------
/// @name Airship Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Handle app init. This should be called from NSNotification center
 * and will record a launch from notification and record the app init even
 * for analytics.
 * @param notification The app did finish launching notification
 */
+ (void)handleAppDidFinishLaunchingNotification:(NSNotification *)notification;

/**
 * Handle a termination event from NSNotification center (forward it to land)
 * @param notification The app termination notification
 */
+ (void)handleAppTerminationNotification:(NSNotification *)notification;

/**
 * Perform teardown on the shared instance. This will automatically be called when an application
 * terminates.
 */
+ (void)land;

/**
 * Sets the shared airship.
 * @param airship The shared airship instance.
 */
+ (void)setSharedAirship:(UAirship * __nullable)airship;

NS_ASSUME_NONNULL_END

@end
