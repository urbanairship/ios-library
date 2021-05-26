/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAAnalytics.h"
#import "UAComponent+Internal.h"
#import "UADate.h"
#import "UADispatcher.h"
#import "UAExtendableAnalyticsHeaders.h"
#import "UAEventManager+Internal.h"

#define kUAMissingSendID @"MISSING_SEND_ID"
#define kUAPushMetadata @"com.urbanairship.metadata"

@class UACustomEvent;
@class UARegionEvent;
@class UAPreferenceDataStore;
@class UARuntimeConfig;

NS_ASSUME_NONNULL_BEGIN


/*
 * SDK-private extensions to Analytics
 */
@interface UAAnalytics () <UAExtendableAnalyticsHeaders, UAEventManagerDelegate>


///---------------------------------------------------------------------------------------
/// @name Analytics Internal Properties
///---------------------------------------------------------------------------------------

/**
 * The conversion send ID.
 */
@property (nonatomic, copy, nullable) NSString *conversionSendID;

/**
 * The conversion push metadata.
 */
@property (nonatomic, copy, nullable) NSString *conversionPushMetadata;

/**
 * The current session ID.
 */
@property (nonatomic, copy, nullable) NSString *sessionID;



///---------------------------------------------------------------------------------------
/// @name Analytics Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method to create an analytics instance.
 * @param airshipConfig The 'AirshipConfig.plist' file
 * @param dataStore The shared preference data store.
 * @param channel The channel instance.
 * @param localeManager A UALocaleManager.
 * @param privacyManager A UAPrivacyManager.
 * @return A new analytics instance.
 */
+ (instancetype)analyticsWithConfig:(UARuntimeConfig *)airshipConfig
                          dataStore:(UAPreferenceDataStore *)dataStore
                            channel:(UAChannel *)channel
                      localeManager:(UALocaleManager *)localeManager
                      privacyManager:(UAPrivacyManager *)privacyManager;


/**
 * Factory method to create an analytics instance. Used for testing.
 *
 * @param airshipConfig The 'AirshipConfig.plist' file
 * @param dataStore The shared preference data store.
 * @param channel The channel instance.
 * @param eventManager An event manager instance.
 * @param notificationCenter The notification center.
 * @param date A UADate instance.
 * @param dispatcher The dispatcher.
 * @param localeManager A UALocaleManager.
 * @param appStateTracker The app state tracker.
 * @param privacyManager A UAPrivacyManager.
 * @return A new analytics instance.
 */
+ (instancetype)analyticsWithConfig:(UARuntimeConfig *)airshipConfig
                          dataStore:(UAPreferenceDataStore *)dataStore
                            channel:(UAChannel *)channel
                       eventManager:(UAEventManager *)eventManager
                 notificationCenter:(NSNotificationCenter *)notificationCenter
                               date:(UADate *)date
                         dispatcher:(UADispatcher *)dispatcher
                      localeManager:(UALocaleManager *)localeManager
                    appStateTracker:(UAAppStateTracker *)appStateTracker
                     privacyManager:(UAPrivacyManager *)privacyManager;

/**
 * Called to notify analytics the app was launched from a push notification.
 * @param notification The push notification.
 */
- (void)launchedFromNotification:(NSDictionary *)notification;

@end

NS_ASSUME_NONNULL_END
