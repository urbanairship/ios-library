/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAEvent.h"

@class UAAppStateTracker;
@class UARuntimeConfig;
@class UAPreferenceDataStore;
@class UAEventAPIClient;
@class UAEventStore;
@class UADelay;
@class UATaskManager;
@class UAChannel;

/**
 * Delegate protocol for the event manager.
 */
@protocol UAEventManagerDelegate <NSObject>
@required

/**
 * Get the current analytics headers.
 */
- (NSDictionary<NSString *, NSString *> *)analyticsHeaders;

@end


/**
 * Event manager handles storing and uploading events to Airship.
 */
@interface UAEventManager : NSObject

// Max database size
#define kMaxTotalDBSizeBytes (NSUInteger)5*1024*1024 // local max of 5MB
#define kMinTotalDBSizeBytes (NSUInteger)10*1024     // local min of 10KB

// Total size in bytes that a given event post is allowed to send.
#define kMaxBatchSizeBytes (NSUInteger)500*1024      // local max of 500KB
#define kMinBatchSizeBytes (NSUInteger)10*1024          // local min of 10KB

// The actual amount of time in seconds that elapse between event-server posts
#define kMinBatchIntervalSeconds (NSTimeInterval)60        // local min of 60s
#define kMaxBatchIntervalSeconds (NSTimeInterval)7*24*3600  // local max of 7 days

// Data store keys
#define kMaxTotalDBSizeUserDefaultsKey @"X-UA-Max-Total"
#define kMaxBatchSizeUserDefaultsKey @"X-UA-Max-Batch"
#define kMaxWaitUserDefaultsKey @"X-UA-Max-Wait"
#define kMinBatchIntervalUserDefaultsKey @"X-UA-Min-Batch-Interval"

///---------------------------------------------------------------------------------------
/// @name Event Manager Internal Properties
///---------------------------------------------------------------------------------------

/**
 * Flag indicating whether event manager uploads are enabled. Defaults to disabled.
 */
@property(atomic, assign) BOOL uploadsEnabled;

/**
 * Event manager delegate.
 */
@property(nonatomic, weak) id<UAEventManagerDelegate> delegate;

///---------------------------------------------------------------------------------------
/// @name Event Manager Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Default factory method.
 *
 * @param config The airship config.
 * @param dataStore The preference data store.
 * @param channel The channel instance.
 * @return UAEventManager instance.
 */
+ (instancetype)eventManagerWithConfig:(UARuntimeConfig *)config
                             dataStore:(UAPreferenceDataStore *)dataStore
                               channel:(UAChannel *)channel;

/**
 * Factory method used for testing.
 *
 * @param config The airship config.
 * @param dataStore The preference data store.
 * @param channel The channel instance.
 * @param eventStore The event data store.
 * @param client The event api client.
 * @param notificationCenter The notification center.
 * @param appStateTracker The app state tracker.
 * @param taskManager The task manager.
 * @param delayProvider A delay provider block.
 * @return UAEventManager instance.
 */
+ (instancetype)eventManagerWithConfig:(UARuntimeConfig *)config
                             dataStore:(UAPreferenceDataStore *)dataStore
                               channel:(UAChannel *)channel
                            eventStore:(UAEventStore *)eventStore
                                client:(UAEventAPIClient *)client
                    notificationCenter:(NSNotificationCenter *)notificationCenter
                       appStateTracker:(UAAppStateTracker *)appStateTracker
                           taskManager:(UATaskManager *)taskManager
                         delayProvider:(UADelay *(^)(NSTimeInterval))delayProvider;

/**
 * Adds an analytic event to be batched and uploaded to Airship.
 *
 * @param event The analytic event.
 * @param eventID The event ID.
 * @param eventDate The event date.
 * @param sessionID The analytic session ID.
 */
- (void)addEvent:(id<UAEvent>)event
         eventID:(NSString *)eventID
       eventDate:(NSDate *)eventDate
       sessionID:(NSString *)sessionID;

/**
 * Deletes all events and cancels any uploads in progress.
 */
- (void)deleteAllEvents;

/**
 * Schedules an analytic upload.
 */
- (void)scheduleUpload;

@end
