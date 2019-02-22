/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>

@class UAInAppMessageManager;
@class UARemoteDataManager;
@class UAPreferenceDataStore;
@class UAPush;

/**
 * Client class to connect the Remote Data and the In App Messaging services.
 * This class parses the remote data payloads, and asks the in app scheduler to
 * create, update, or delete in-app messages, as appropriate.
 */
@interface UAInAppRemoteDataClient : NSObject

/**
 * New user cut off time. Any schedules that have
 * a new user condition will be dropped if the schedule create time is after the
 * cut off time.
 */
@property (nonatomic, strong) NSDate *scheduleNewUserCutOffTime;

/**
 * Operation queue. Exposed for testing.
 */
@property (nonatomic, readonly) NSOperationQueue *operationQueue;

/**
 * Create a remote data client for in-app messaging.
 *
 * @param delegate The delegate to be used to schedule in-app messages.
 * @param remoteDataManager The remote data manager.
 * @param dataStore A UAPreferenceDataStore to store persistent preferences
 * @param push The system UAPush instance
 */
+ (instancetype)clientWithScheduler:(UAInAppMessageManager *)delegate
                  remoteDataManager:(UARemoteDataManager *)remoteDataManager
                          dataStore:(UAPreferenceDataStore *)dataStore
                               push:(UAPush *)push;

@end
