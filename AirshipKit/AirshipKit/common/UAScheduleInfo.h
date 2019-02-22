/* Copyright Urban Airship and Contributors */

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
 * The schedule's priority. Schedules are executed by priority in ascending order.
 *
 * Optional. Defaults to 0.
 */
@property(nonatomic, assign) NSInteger priority;

/**
 * The max number of times the schedule may be executed.
 *
 * Optional. Defaults to 1.
 *
 * For in-app messages, if the audience condition checks fail, and
 * the miss behavior is `skip`, the triggered schedule will not count towards
 * the limit.
 */
@property(nonatomic, assign) NSUInteger limit;

/**
 * Array of triggers. Triggers define conditions on when to execute the schedule.
 *
 * An array with between 1 and 10 triggers is required.
 */
@property(nonatomic, copy, nullable) NSArray<UAScheduleTrigger *> *triggers;

/**
 * The schedule's start time.
 *
 * Optional.
 */
@property(nonatomic, strong, nullable) NSDate *start;

/**
 * The schedule's end time. After the end time the schedule will be finished.
 *
 * Optional.
 */
@property(nonatomic, strong, nullable) NSDate *end;

/**
 * The schedule's delay.
 *
 * Optional.
 */
@property(nonatomic, strong, nullable) UAScheduleDelay *delay;

/**
 * The schedule's edit grace period. The amount of time the schedule will still be editable after it has expired
 * or finished executing.
 *
 * Optional. Defaults to 0.
 */
@property(nonatomic, assign) NSTimeInterval editGracePeriod;

/**
 * The schedule's interval. The amount of time to pause the schedule after executing.
 *
 * Optional. Defaults to 0.
 */
@property(nonatomic, assign) NSTimeInterval interval;

@end

/**
 * Defines the scheduled action.
 *
 * @note This object is built using `UAScheduleInfoBuilder`.
 */
@interface UAScheduleInfo : NSObject

///---------------------------------------------------------------------------------------
/// @name Schedule Info Properties
///---------------------------------------------------------------------------------------

/**
 * The schedule's priority. Schedules are executed by priority in ascending order.
 */
@property(nonatomic, readonly) NSInteger priority;

/**
 * Array of triggers. Triggers define conditions on when to execute the schedule.
 */
@property(nonatomic, readonly) NSArray<UAScheduleTrigger *> *triggers;

/**
 * The max number of times the schedule may be executed.
 *
 * For in-app messages, if the audience condition checks fail, and
 * the miss behavior is `skip`, the triggered schedule will not count towards
 * the limit.
 */
@property(nonatomic, readonly) NSUInteger limit;

/**
 * The schedule's start time.
 */
@property(nonatomic, nullable, readonly) NSDate *start;

/**
 * The schedule's end time. After the end time the schedule will be finished.
 */
@property(nonatomic, nullable, readonly) NSDate *end;

/**
 * The schedule's delay.
 */
@property(nonatomic, nullable, readonly) UAScheduleDelay *delay;

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


