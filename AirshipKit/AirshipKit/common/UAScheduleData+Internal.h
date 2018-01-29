/* Copyright 2018 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@class UAScheduleDelayData;
@class UAScheduleTriggerData;

/**
 * CoreData class representing the backing data for
 * a UASchedule.
 *
 * This class should not ordinarily be used directly.
 */
@interface UAScheduleData : NSManagedObject

///---------------------------------------------------------------------------------------
/// @name Schedule Data Properties
///---------------------------------------------------------------------------------------

/**
 * The schedule's identifier.
 */
@property (nullable, nonatomic, retain) NSString *identifier;

/**
 * The schedule's group.
 */
@property (nullable, nonatomic, retain) NSString *group;

/**
 * Number of times the actions will be triggered until the schedule is
 * canceled.
 */
@property (nullable, nonatomic, retain) NSNumber *limit;

/**
 * The number of times the action has been triggered.
 */
@property (nullable, nonatomic, retain) NSNumber *triggeredCount;

/**
 * The schedule data payload.
 */
@property (nullable, nonatomic, retain) NSString *data;

/**
 * The schedule's priority. Priority is optional and defaults to 0. Schedules are
 * executed by priority in ascending order.
 */
@property(nullable, nonatomic, retain) NSNumber *priority;

/**
 * Set of triggers. Triggers define conditions on when to run
 * the actions.
 */
@property (nullable, nonatomic, retain) NSSet<UAScheduleTriggerData *> *triggers;

/**
 * The schedule's start time.
 */
@property (nullable, nonatomic, retain) NSDate *start;

/**
 * The schedule's end time. After the end time the schedule will be canceled.
 */
@property (nullable, nonatomic, retain) NSDate *end;

/**
 * The schedule's delay in seconds.
 */
@property (nullable, nonatomic, retain) UAScheduleDelayData *delay;

/**
 * The schedule's execution state.
 */
@property (nullable, nonatomic, retain) NSNumber *executionState;

/**
 * The schedule's execution state change date.
 */
@property (nullable, nonatomic, retain, readonly) NSDate *executionStateChangeDate;

/**
 * The delayed execution date. This delay date takes precedent over the delay in seconds.
 */
@property (nullable, nonatomic, retain) NSDate *delayedExecutionDate;

/**
 * The schedule's edit grace period in seconds.
 */
@property(nullable, nonatomic, retain) NSNumber *editGracePeriod;

/**
 * The schedule's interval in seconds.
 */
@property(nullable, nonatomic, retain) NSNumber *interval;

@end

NS_ASSUME_NONNULL_END
