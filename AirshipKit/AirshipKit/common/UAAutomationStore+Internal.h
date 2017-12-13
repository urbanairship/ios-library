/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>

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
 * @return Automation store.
 */
+ (instancetype)automationStoreWithStoreName:(NSString *)storeName;

/**
 * Saves the UAActionSchedule to the data store.
 *
 * @param schedule The schedule to save.
 * @param limit The max number of schedules to allow.
 * @param completionHandler Completion handler when the operation is finished. `YES` if the
 * schedule was saved, `NO` if the schedule failed to save or the data store contains
 * more schedules then the specified limit.
 */
- (void)saveSchedule:(UASchedule *)schedule limit:(NSUInteger)limit completionHandler:(void (^)(BOOL))completionHandler;

/**
 * Save multiple UAActionSchedules to the data store.
 *
 * @param schedules The schedules to save.
 * @param limit The max number of schedules to allow.
 * @param completionHandler Completion handler when the operation is finished. `YES` if the
 * schedules were saved, `NO` if the schedules failed to save or the number of schedules in the
 * data store would exceed the specified limit.
 */
- (void)saveSchedules:(NSArray<UASchedule *> *)schedules limit:(NSUInteger)limit completionHandler:(void (^)(BOOL))completionHandler;

/**
 * Deletes schedules from the data store.
 *
 * @param predicate The predicate matcher.
 */
- (void)deleteSchedulesWithPredicate:(NSPredicate *)predicate;

/**
 * Fetches schedule data from the data store. The schedule data can only be modified
 * in the completion handler.
 *
 * @param predicate The predicate matcher.
 * @param limit The request's limit
 * @param completionHandler Completion handler with an array of the matching schedule data.
 */
- (void)fetchSchedulesWithPredicate:(NSPredicate *)predicate
                              limit:(NSUInteger)limit
                  completionHandler:(void (^)(NSArray<UAScheduleData *> *))completionHandler;

/**
 * Fetches trigger data from the data store. The trigger data can only be modified
 * in the completion handler.
 *
 * @param predicate The predicate matcher.
 * @param completionHandler Completion handler with an array of the matching trigger data.
 */
- (void)fetchTriggersWithPredicate:(NSPredicate *)predicate
                 completionHandler:(void (^)(NSArray<UAScheduleTriggerData *> *))completionHandler;

/**
 * Waits for the store to become idle and then returns. Used by Unit Tests.
 */
- (void)waitForIdle;


@end
