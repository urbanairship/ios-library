/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAScheduleTrigger+Internal.h"
#import "UADate+Internal.h"

NS_ASSUME_NONNULL_BEGIN

@class UASchedule;
@class UAScheduleData;
@class UAScheduleTriggerData;
@class UAConfig;

/**
 * Manager class for the Automation CoreData store.
 */
@interface UAAutomationStore : NSObject

///---------------------------------------------------------------------------------------
/// @name Automation Store Internal Methods
///---------------------------------------------------------------------------------------

/**
* Factory method for automation store.
*
* @param storeName The store name.
* @param scheduleLimit The maximum number of schedules available for storage
* @param inMemory Whether to use an in-memory database. If `NO` the store will default to SQLite.
* @param date The UADate instance.
*
* @return Automation store.
*/
+ (instancetype)automationStoreWithStoreName:(NSString *)storeName scheduleLimit:(NSUInteger)scheduleLimit inMemory:(BOOL)inMemory date:(UADate *)date;

/**
 * Factory method for automation store.
 *
 * @param storeName The store name.
 * @param scheduleLimit The maximum number of schedules available for storage

 * @return Automation store.
 */
+ (instancetype)automationStoreWithStoreName:(NSString *)storeName scheduleLimit:(NSUInteger)scheduleLimit;

/**
 * Saves the UAActionSchedule to the data store.
 *
 * @param schedule The schedule to save.
 * @param completionHandler Completion handler when the operation is finished. `YES` if the
 * schedule was saved, `NO` if the schedule failed to save or the data store contains
 * more schedules then the specified limit.
 */
- (void)saveSchedule:(UASchedule *)schedule completionHandler:(void (^)(BOOL))completionHandler;

/**
 * Save multiple UAActionSchedules to the data store.
 *
 * @param schedules The schedules to save.
 * @param completionHandler Completion handler when the operation is finished. `YES` if the
 * schedules were saved, `NO` if the schedules failed to save or the number of schedules in the
 * data store would exceed the specified limit.
 */
- (void)saveSchedules:(NSArray<UASchedule *> *)schedules completionHandler:(void (^)(BOOL))completionHandler;

/**
 * Deletes the schedule corresponding to the provided identifier.
 *
 * @param scheduleID A schedule identifier.
 */
- (void)deleteSchedule:(NSString *)scheduleID;

/**
 * Deletes all schedules corresponding to the provided identifier.
 *
 * @param groupID A group identifier.
 */
- (void)deleteSchedules:(NSString *)groupID;

/**
 * Deletes all schedules.
 */
- (void)deleteAllSchedules;

/**
 * Gets all schedules corresponding to the provided identifier.
 *
 * @param groupID A group identifier.
 * @param completionHandler Completion handler called back with the retrieved schedule data.
 */
- (void)getSchedules:(NSString *)groupID completionHandler:(void (^)(NSArray<UAScheduleData *> *))completionHandler;

/**
 * Gets all un-ended schedules.
 *
 * @param completionHandler Completion handler called back with the retrieved schedule data.
 */
- (void)getSchedules:(void (^)(NSArray<UAScheduleData *> *))completionHandler;

/**
 * Gets all schedules, including schedules that have ended.
 *
 * @param completionHandler Completion handler called back with the retrieved schedule data.
 */
- (void)getAllSchedules:(void (^)(NSArray<UAScheduleData *> *))completionHandler;

/**
 * Gets the schedule corresponding to the provided identifier.
 *
 * @param scheduleID A schedule identifier.
 * @param completionHandler Completion handler called back with the retrieved schedule data.
 */
- (void)getSchedule:(NSString *)scheduleID completionHandler:(void (^)(UAScheduleData *))completionHandler;

/**
 * Gets the schedules with the corresponding state.
 *
 * @param state An array of schedule state.
 * @param completionHandler Completion handler called back with the retrieved schedule data.
 */
- (void)getSchedulesWithStates:(NSArray *)state completionHandler:(void (^)(NSArray<UAScheduleData *> *))completionHandler;

/**
 * Gets all expired schedules that have not exceeded their grace period.
 *
 * @param completionHandler Completion handler called back with the retrieved schedule data.
 */
- (void)getActiveExpiredSchedules:(void (^)(NSArray<UAScheduleData *> *))completionHandler;

/**
 * Gets all active triggers corresponding to the provided schedule identifier and trigger type.
 *
 * @param scheduleID A schedule identifier. If this parameter is nil, all schedules will be queried.
 * @param type A trigger type
 * @param completionHandler Completion handler called back with the retrieved trigger data.
 */
- (void)getActiveTriggers:(nullable NSString *)scheduleID
                     type:(UAScheduleTriggerType)type
        completionHandler:(void (^)(NSArray<UAScheduleTriggerData *> *triggers))completionHandler;

/**
 * Gets the schedule count.
 *
 * @param completionHandler Completion handler called back with the retrieved schedule count as an NSNumber.
 */
- (void)getScheduleCount:(void (^)(NSNumber *))completionHandler;

/**
 * Waits for the store to become idle and then returns. Used by Unit Tests.
 */
- (void)waitForIdle;

/**
 * Shuts down the store and prevents any subsequent interaction with the managed context. Used by Unit Tests.
 */
- (void)shutDown;

NS_ASSUME_NONNULL_END

@end
