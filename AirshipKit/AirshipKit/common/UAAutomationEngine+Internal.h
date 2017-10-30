/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UASchedule.h"
#import "UAAutomationStore+Internal.h"
#import "UAAnalytics+Internal.h"
#import <UIKit/UIKit.h>
#import "UAScheduleInfo.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Schedule execution states.
 */
typedef NS_ENUM(NSUInteger,UAScheduleState) {
    UAScheduleStateIdle = 0,
    UAScheduleStatePendingExecution = 1,
    UAScheduleStateExecuting = 2
};


/**
 * Automation engine delegate
 */
@protocol UAAutomationEngineDelegate

/**
 * Creates a schedule info from a builder.
 *
 * @param builder The schedule info builder.
 * @returns Schedule info.
 */
- (UAScheduleInfo *)createScheduleInfoWithBuilder:(UAScheduleInfoBuilder *)builder;


/**
 * Checks if a schedule is ready to execute.
 *
 * @param schedule The schedule.
 * @returns `YES` if the schedule should be executed, otherwise `NO`.
 */
- (BOOL)isScheduleReadyToExecute:(UASchedule *)schedule;

/**
 * Executes a schedule.
 *
 * @param schedule The schedule.
 * @param completionHandler Completion handler when the schedule is finished executing.
 */
- (void)executeSchedule:(UASchedule *)schedule
      completionHandler:(void (^)(void))completionHandler;

@end

/**
 * Automation engine.
 */
@interface UAAutomationEngine : NSObject

/**
 * Automation engine delegate.
 */
@property (nonatomic, weak) id<UAAutomationEngineDelegate> delegate;

/**
 * Automation engine Core Data store.
 */
@property (nonatomic, strong) UAAutomationStore *automationStore;


/**
 * Automation constructor.
 */
+ (instancetype)automationEngineWithStoreName:(NSString *)storeName scheduleLimit:(NSUInteger)limit;


/**
 * Starts the Automation Engine.
 */
- (void)start;

/**
 * Stops the Automation Engine.
 */
- (void)stop;

/**
 * Schedules a single schedule.
 *
 * @param scheduleInfo The schedule information.
 * @param completionHandler A completion handler.
 * If the schedule info is invalid, the schedule will be nil.
 */
- (void)schedule:(UAScheduleInfo *)scheduleInfo completionHandler:(nullable void (^)(UASchedule * __nullable))completionHandler;

/**
 * Cancels a schedule with the given identifier.
 *
 * @param identifier A schedule identifier.
 */
- (void)cancelScheduleWithIdentifier:(NSString *)identifier;

/**
 * Cancels all schedules of the given group.
 *
 * @param group A schedule group.
 */
- (void)cancelSchedulesWithGroup:(NSString *)group;

/**
 * Cancels all schedules.
 */
- (void)cancelAll;

/**
 * Gets the schedule with the given identifier.
 *
 * @param identifier A schedule identifier.
 * @param completionHandler The completion handler with the result.
 */
- (void)getScheduleWithIdentifier:(NSString *)identifier
                completionHandler:(void (^)(UASchedule * __nullable))completionHandler;

/**
 * Gets all schedules.
 *
 * @param completionHandler The completion handler with the result.
 */
- (void)getSchedules:(void (^)(NSArray<UASchedule *> *))completionHandler;

/**
 * Gets all schedules of the given group.
 *
 * @param group The schedule group.
 * @param completionHandler The completion handler with the result.
 */
- (void)getSchedulesWithGroup:(NSString *)group
            completionHandler:(void (^)(NSArray<UASchedule *> *))completionHandler;

@end

NS_ASSUME_NONNULL_END

