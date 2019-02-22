/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAAnalytics.h"
#import "UAComponent+Internal.h"
#import "UADate+Internal.h"
#import "UADispatcher+Internal.h"

#define kUAAnalyticsEnabled @"UAAnalyticsEnabled"
#define kUAMissingSendID @"MISSING_SEND_ID"
#define kUAPushMetadata @"com.urbanairship.metadata"

@class UACustomEvent;
@class UARegionEvent;
@class UAPreferenceDataStore;
@class UAConfig;
@class UAEventManager;

NS_ASSUME_NONNULL_BEGIN


/*
 * SDK-private extensions to Analytics
 */
@interface UAAnalytics ()

extern NSString *const UACustomEventAdded;
extern NSString *const UARegionEventAdded;
extern NSString *const UAScreenTracked;
extern NSString *const UAEventKey;
extern NSString *const UAScreenKey;

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
 * The conversion rich push ID.
 */
@property (nonatomic, copy, nullable) NSString *conversionRichPushID;

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
 * @return A new analytics instance.
 */
+ (instancetype)analyticsWithConfig:(UAConfig *)airshipConfig
                          dataStore:(UAPreferenceDataStore *)dataStore;


/**
 * Factory method to create an analytics instance. Used for testing.
 *
 * @param airshipConfig The 'AirshipConfig.plist' file
 * @param dataStore The shared preference data store.
 * @param eventManager An event manager instance.
 * @param notificationCenter The notification center.
 * @param date A UADate instance.
 * @param dispatcher The dispatcher.
 * @return A new analytics instance.
 */
+ (instancetype)analyticsWithConfig:(UAConfig *)airshipConfig
                          dataStore:(UAPreferenceDataStore *)dataStore
                       eventManager:(UAEventManager *)eventManager
                 notificationCenter:(NSNotificationCenter *)notificationCenter
                               date:(UADate *)date
                         dispatcher:(UADispatcher *)dispatcher;

/**
 * Called to notify analytics the app was launched from a push notification.
 * @param notification The push notification.
 */
- (void)launchedFromNotification:(NSDictionary *)notification;

/**
 * Cancels any scheduled event uploads.
 */
- (void)cancelUpload;

@end

NS_ASSUME_NONNULL_END
