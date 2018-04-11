/* Copyright 2018 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAScheduleTrigger.h"
#import "UAScheduleDelay.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Max number of triggers a schedule can support.
 */
extern NSUInteger const UAScheduleInfoMaxTriggers;

/**
 * Builder class for UAScheduleInfo.
 */
@interface UAScheduleInfoBuilder : NSObject

///---------------------------------------------------------------------------------------
/// @name Schedule Info Builder Properties
///---------------------------------------------------------------------------------------

/**
 * The schedule's priority. Priority is optional and defaults to 0. Schedules are
 * executed by priority in ascending order.
 */
@property(nonatomic, assign) NSInteger priority;

/**
 * Number of times the actions will be triggered until the schedule is
 * finished.
 */
@property(nonatomic, assign) NSUInteger limit;

/**
 * Array of triggers. Triggers define conditions on when to run
 * the actions.
 */
@property(nonatomic, strong, nullable) NSArray<UAScheduleTrigger *> *triggers;

/**
 * The schedule's start time.
 */
@property(nonatomic, strong, nullable) NSDate *start;

/**
 * The schedule's end time. After the end time the schedule will be finished.
 */
@property(nonatomic, strong, nullable) NSDate *end;

/**
 * The schedule's delay.
 */
@property(nonatomic, strong, nullable) UAScheduleDelay *delay;

/**
 * The schedule's edit grace period. The amount of time the schedule will still be editable after it has expired
 * or finished executing.
 */
@property(nonatomic, assign) NSTimeInterval editGracePeriod;

/**
 * The schedule's interval. The amount of time to pause the schedule after executing.
 */
@property(nonatomic, assign) NSTimeInterval interval;

@end

/**
 * Defines the scheduled action.
 */
@interface UAScheduleInfo : NSObject

///---------------------------------------------------------------------------------------
/// @name Schedule Info Properties
///---------------------------------------------------------------------------------------

/**
* The schedule's priority. Priority is optional and defaults to 0. Schedules are
* executed by priority in ascending order.
*/
@property(nonatomic, readonly) NSInteger priority;

/**
 * Array of triggers. Triggers define conditions on when to run
 * the actions.
 */
@property(nonatomic, readonly) NSArray<UAScheduleTrigger *> *triggers;

/**
 * Number of times the actions will be triggered until the schedule is
 * canceled.
 */
@property(nonatomic, readonly) NSUInteger limit;

/**
 * The schedule's start time.
 */
@property(nonatomic, readonly) NSDate *start;

/**
 * The schedule's end time. After the end time the schedule will be canceled.
 */
@property(nonatomic, readonly) NSDate *end;

/**
 * The schedule's delay.
 */
@property(nonatomic, readonly) UAScheduleDelay *delay;

/**
 * The schedule's edit grace period.
 */
@property(nonatomic, readonly) NSTimeInterval editGracePeriod;

/**
 * The schedule's interval.
 */
@property(nonatomic, readonly) NSTimeInterval interval;

/**
 * Checks if the schedule info is valid. A valid schedule
 * contains between 1 to 10 triggers, if a delay is defined it must be valid,
 * and the end time must be after the start time. Invalid schedules will not be scheduled.
 */
@property(nonatomic, readonly) BOOL isValid;

///---------------------------------------------------------------------------------------
/// @name Schedule Info Management
///---------------------------------------------------------------------------------------

/**
 * Checks if the schedule info is equal to another schedule info
 *
 * @param scheduleInfo The other schedule info to compare against.
 * @return `YES` if the schedule infos are equal, otherwise `NO`.
 */
- (BOOL)isEqualToScheduleInfo:(nullable UAScheduleInfo *)scheduleInfo;

@end

NS_ASSUME_NONNULL_END


