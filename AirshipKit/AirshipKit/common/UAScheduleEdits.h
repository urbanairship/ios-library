/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>

/**
 * Builder class for UAScheduleEdits.
 */
@interface UAScheduleEditsBuilder : NSObject

///---------------------------------------------------------------------------------------
/// @name Schedule Edits Builder Properties
///---------------------------------------------------------------------------------------

/**
 * The schedule's priority. Schedules are executed by priority in ascending order.
 */
@property(nonatomic, strong, nullable) NSNumber *priority;

/**
 * Number of times the actions will be triggered until the schedule is
 * finished.
 */
@property(nonatomic, strong, nullable) NSNumber *limit;

/**
 * The schedule's start time.
 */
@property(nonatomic, strong, nullable) NSDate *start;

/**
 * The schedule's end time. After the end time the schedule will be finished.
 */
@property(nonatomic, strong, nullable) NSDate *end;

/**
 * The schedule's edit grace period. The amount of time the schedule will still be editable after it has been expired
 * or finished executing.
 */
@property(nonatomic, strong, nullable) NSNumber *editGracePeriod;

/**
 * The schedule's interval. The amount of time to pause the schedule after executing.
 */
@property(nonatomic, strong, nullable) NSNumber *interval;

@end

/**
 * Schedule edits.
 */
@interface UAScheduleEdits : NSObject

///---------------------------------------------------------------------------------------
/// @name Schedule Edits Properties
///---------------------------------------------------------------------------------------

/**
 * The schedule's priority. Priority is optional and defaults to 0. Schedules are
 * executed by priority in ascending order.
 */
@property(nonatomic, readonly, nullable) NSNumber *priority;

/**
 * Number of times the actions will be triggered until the schedule is
 * finished.
 */
@property(nonatomic, readonly, nullable) NSNumber *limit;

/**
 * The schedule's start time.
 */
@property(nonatomic, readonly, nullable) NSDate *start;

/**
 * The schedule's end time. After the end time the schedule will be finished.
 */
@property(nonatomic, readonly, nullable) NSDate *end;

/**
 * The schedule's edit grace period. The amount of time the schedule will still be editable after it has expired
 * or finished executing.
 */
@property(nonatomic, readonly, nullable) NSNumber *editGracePeriod;

/**
 * The schedule's interval. The amount of time to pause the schedule after executing.
 */
@property(nonatomic, readonly, nullable) NSNumber *interval;

@end
