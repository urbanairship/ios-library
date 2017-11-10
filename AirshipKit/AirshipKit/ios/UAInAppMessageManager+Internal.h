/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessageManager.h"
#import "UAAutomationEngine+Internal.h"
#import "UAInAppMessage.h"
#import "UAInAppMessageScheduleInfo.h"
#import "UAInAppMessageAdapter.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * In-app message manager provides a control interface for creating,
 * canceling and executing in-app message schedules.
 */
@interface UAInAppMessageManager ()

/**
* Display lock interval.
*/
@property(nonatomic, assign) NSTimeInterval displayInterval;

/**
 * Init method.
 *
 * @param automationEngine Automation engine.
 */
+ (instancetype)managerWithAutomationEngine:(UAAutomationEngine *)automationEngine;

/**
 * Init method.
 *
 * @param config The UAConfigInstance.
 * @param storeName The store name.
 */
+ (instancetype)managerWithConfig:(UAConfig *)config storeName:(NSString *)storeName;


// UAAutomationEngineDelegate methods for testing

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
- (void)executeSchedule:(nonnull UASchedule *)schedule
      completionHandler:(void (^)(void))completionHandler;

@end

NS_ASSUME_NONNULL_END

