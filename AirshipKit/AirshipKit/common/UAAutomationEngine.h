/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UASchedule.h"
#import <UIKit/UIKit.h>
#import "UAScheduleInfo.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Automation engine delegate
 */
@protocol UAAutomationEngineDelegate <NSObject>

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

