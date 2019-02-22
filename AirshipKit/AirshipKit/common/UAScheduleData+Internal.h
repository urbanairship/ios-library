/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@class UAScheduleDelayData;
@class UAScheduleTriggerData;

/**
 * Schedule execution states.
 */
typedef NS_ENUM(NSUInteger, UAScheduleState) {
    // The state values do not define the order.

    /**
     * Schedule is idle.
     */
    UAScheduleStateIdle = 0,

    /**
     * Schedule is waiting for its time delay to expire.
     */
    UAScheduleStateTimeDelayed = 5,

    /**
     * Schedule is being prepared.
     */
    UAScheduleStatePreparingSchedule = 6,

    /**
     * Schedule is waiting for app state conditions to be met.
     */
    UAScheduleStateWaitingScheduleConditions = 1,

    /**
     * Schedule is executing.
     */
    UAScheduleStateExecuting = 2,

    /**
     * Schedule is paused.
     */
    UAScheduleStatePaused = 3,

    /**
     * Schedule is finished.
     */
    UAScheduleStateFinished = 4
};

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

extern NSUInteger const UAScheduleDataVersion;

/**
 * The schedule's identifier.
 */
@property (nullable, nonatomic, retain) NSString *identifier;

/**
 * The schedule's group.
 */
@property (nullable, nonatomic, retain) NSString *group;

/**
 * The max number of times the schedule may be successfully executed.
 */
@property (nullable, nonatomic, retain) NSNumber *limit;

/**
 * The number of times the schedule has been triggered and executed.
 *
 * If the schedule prepare result is `skip`, this number will not be incremented.
 */
@property (nullable, nonatomic, retain) NSNumber *triggeredCount;

/**
 * The schedule data payload.
 */
@property (nullable, nonatomic, retain) NSString *data;

/**
 * The schedule's data version.
 */
@property (nonatomic, retain) NSNumber *dataVersion;

/**
 * The schedule's priority. Priority is optional and defaults to 0. Schedules are
 * executed by priority in ascending order.
 */
@property(nullable, nonatomic, retain) NSNumber *priority;

/**
 * Array of triggers. Triggers define conditions on when to execute the schedule.
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

/**
 * Whether the scheudle has exceeded its limit.
 */
- (BOOL)isOverLimit;

/**
 * Whether the scheudle has expired.
 */
- (BOOL)isExpired;


@end

NS_ASSUME_NONNULL_END
