/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAScheduleTrigger+Internal.h"
#import "UAAirshipAutomationCoreImport.h"
#import "UASchedule+Internal.h"

NS_ASSUME_NONNULL_BEGIN

@class UAScheduleData;
@class UAScheduleTriggerData;
@class UARuntimeConfig;
@class UAScheduleTriggerContext;
@class UADate;

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
* @param config The config.
* @param scheduleLimit The maximum number of schedules available for storage
* @param inMemory Whether to use an in-memory database. If `NO` the store will default to SQLite.
* @param date The UADate instance.
*
* @return Automation store.
*/
+ (instancetype)automationStoreWithConfig:(UARuntimeConfig *)config
                            scheduleLimit:(NSUInteger)scheduleLimit
                                 inMemory:(BOOL)inMemory
                                     date:(UADate *)date;

/**
 * Factory method for automation store.
 *
 * @param config The config.
 * @param scheduleLimit The maximum number of schedules available for storage

 * @return Automation store.
 */
+ (instancetype)automationStoreWithConfig:(UARuntimeConfig *)config
                            scheduleLimit:(NSUInteger)scheduleLimit;

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
 * Gets all schedules corresponding to the provided group.
 *
 * @param groupID A group identifier.
 * @param completionHandler Completion handler called back with the retrieved schedule data.
 */
- (void)getSchedules:(NSString *)groupID completionHandler:(void (^)(NSArray<UAScheduleData *> *))completionHandler;

/**
 * Gets all schedules corresponding to the provided group and type.
 *
 * @param groupID A group identifier.
 * @param scheduleType The schedule type.
 * @param completionHandler Completion handler called back with the retrieved schedule data.
 */
- (void)getSchedules:(NSString *)groupID
                type:(UAScheduleType)scheduleType
   completionHandler:(void (^)(NSArray<UAScheduleData *> *))completionHandler;

/**
 * Gets all un-ended schedules.
 *
 * @param completionHandler Completion handler called back with the retrieved schedule data.
 */
- (void)getSchedules:(void (^)(NSArray<UAScheduleData *> *))completionHandler;

/**
 * Gets the schedule corresponding to the given identifier.
 *
 * @param scheduleID A schedule identifier.
 * @param completionHandler Completion handler called back with the retrieved schedule data, or nil if the schedule was not found.
 */
- (void)getSchedule:(NSString *)scheduleID completionHandler:(void (^)(UAScheduleData * _Nullable))completionHandler;

/**
 * Gets the schedule corresponding to the given identifier and type.
 *
 * @param scheduleID A schedule identifier.
 * @param scheduleType The schedule type.
 * @param completionHandler Completion handler called back with the retrieved schedule data, or nil if the schedule was not found.
 */
- (void)getSchedule:(NSString *)scheduleID
               type:(UAScheduleType)scheduleType
  completionHandler:(void (^)(UAScheduleData * _Nullable))completionHandler;


/**
 * Gets the schedules with the corresponding state.
 *
 * @param state An array of schedule state.
 * @param completionHandler Completion handler called back with the retrieved schedule data.
 */
- (void)getSchedulesWithStates:(NSArray *)state
             completionHandler:(void (^)(NSArray<UAScheduleData *> *))completionHandler;

/**
 * Gets the schedules with the corresponding type.
 *
 * @param scheduleType The schedule type.
 * @param completionHandler Completion handler called back with the retrieved schedule data.
 */
- (void)getSchedulesWithType:(UAScheduleType)scheduleType
           completionHandler:(void (^)(NSArray<UAScheduleData *> *))completionHandler;

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
 * @param triggerType The trigger type.
 * @param completionHandler Completion handler called back with the retrieved trigger data.
 */
- (void)getActiveTriggers:(nullable NSString *)scheduleID
                     type:(UAScheduleTriggerType)triggerType
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
