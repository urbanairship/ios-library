/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAAirshipAutomationCoreImport.h"
#import "UASchedule.h"
#import "UAScheduleEdits.h"
#import "UAFrequencyConstraint+Internal.h"

@protocol UARemoteDataProvider;
@class UAPreferenceDataStore;
@class UAChannel;

NS_ASSUME_NONNULL_BEGIN

/**
 * Client delegate.
 */
@protocol UAInAppRemoteDataClientDelegate  <NSObject>

/**
 * Gets schedules.
 *
 * @param completionHandler The completion handler to be called when fetch operation completes.
 */
- (void)getSchedules:(void (^)(NSArray<UASchedule *> *))completionHandler;


/**
 * Schedules multiple in-app messages.
 *
 * @param schedules The schedule info for the messages.
 * @param completionHandler The completion handler to be called when scheduling completes.
 */
- (void)scheduleMultiple:(NSArray<UASchedule *> *)schedules completionHandler:(void (^)(BOOL))completionHandler;


/**
 * Edits a schedule.
 *
 * @param identifier A schedule identifier.
 * @param edits The edits to apply.
 * @param completionHandler The completion handler with the result.
 */
- (void)editScheduleWithID:(NSString *)identifier
                     edits:(UAScheduleEdits *)edits
         completionHandler:(nullable void (^)(BOOL))completionHandler;

/**
 * Called with updated constraints.
 * @param constraints The updated constraints.
 */
- (void)updateConstraints:(NSArray<UAFrequencyConstraint *> *)constraints;

@end

/**
 * Client class to connect the Remote Data and the In App Messaging services.
 * This class parses the remote data payloads, and asks the in app scheduler to
 * create, update, or delete in-app messages, as appropriate.
 */
@interface UAInAppRemoteDataClient : NSObject

/**
 * Client delegate.
 */
@property (nonatomic, weak) id<UAInAppRemoteDataClientDelegate> delegate;

/**
 * New user cut off time.
 */
@property (nonatomic, readonly) NSDate *scheduleNewUserCutOffTime;

/**
 * Create a remote data client for in-app messaging.
 *
 * @param remoteDataProvider The remote data provider.
 * @param dataStore A UAPreferenceDataStore to store persistent preferences
 * @param channel The channel.
 */
+ (instancetype)clientWithRemoteDataProvider:(id<UARemoteDataProvider>)remoteDataProvider
                                   dataStore:(UAPreferenceDataStore *)dataStore
                                     channel:(UAChannel *)channel;

+ (instancetype)clientWithRemoteDataProvider:(id<UARemoteDataProvider>)remoteDataProvider
                                   dataStore:(UAPreferenceDataStore *)dataStore
                                     channel:(UAChannel *)channel
                              operationQueue:(NSOperationQueue *)operationQueue
                                  SDKVersion:(NSString *)SDKVersion;

/**
 * Notifies when the schedules have been updated.
 *
 * @param completionHandler The completion handler to run when check completes.
 */
- (void)notifyOnUpdate:(void (^)(void))completionHandler;

/**
 * Subscribes to updates.
 */
- (void)subscribe;

/**
 * Unsubscribes from updates.
 */
- (void)unsubscribe;

/**
 * Checks if a schedule is remote.
 * @param schedule The schedule.
 * @returns `YES` is remote, otherwise `NO`.
 */
- (BOOL)isRemoteSchedule:(UASchedule *)schedule;

/**
 * Checks if a schedule is remote and up to date.
 * @param schedule The schedule
 * @returns `YES` is remote and up to date, otherwise `NO`.
 */
- (BOOL)isScheduleUpToDate:(UASchedule *)schedule;

/**
 * Attempts to refresh remote data.
 * @param completionHandler The completion handler.
 */
- (void)attemptRemoteDataRefreshWithCompletionHandler:(void (^)(void))completionHandler;

@end

NS_ASSUME_NONNULL_END
