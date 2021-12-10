/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@class UAScheduleDelayData;
@class UAScheduleTriggerData;
@class UAScheduleTriggerContext;

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
@property (nullable, nonatomic, strong) NSString *identifier;

/**
 * The schedule's group.
 */
@property (nullable, nonatomic, strong) NSString *group;

/**
 * The max number of times the schedule may be successfully executed.
 */
@property (nullable, nonatomic, strong) NSNumber *limit;

/**
 * The number of times the schedule has been triggered and executed.
 *
 * If the schedule prepare result is `skip` or `invalidate`, this number will not be incremented.
 */
@property (nullable, nonatomic, strong) NSNumber *triggeredCount;

/**
 * The schedule data payload.
 */
@property (nullable, nonatomic, copy) NSString *data;

/**
 * The metadata payload.
 *
 * Metadata payload contain important schedule metadata such as locale.
 */
@property (nullable, nonatomic, copy) NSString *metadata;

/**
 * The schedule's data version.
 */
@property (nonatomic, strong) NSNumber *dataVersion;

/**
 * The schedule's priority. Priority is optional and defaults to 0. Schedules are
 * executed by priority in ascending order.
 */
@property(nullable, nonatomic, strong) NSNumber *priority;

/**
 * Array of triggers. Triggers define conditions on when to execute the schedule.
 */
@property (nullable, nonatomic, copy) NSSet<UAScheduleTriggerData *> *triggers;

/**
 * The schedule's start time.
 */
@property (nullable, nonatomic, strong) NSDate *start;

/**
 * The schedule's end time. After the end time the schedule will be canceled.
 */
@property (nullable, nonatomic, strong) NSDate *end;

/**
 * The schedule's delay in seconds.
 */
@property (nullable, nonatomic, strong) UAScheduleDelayData *delay;

/**
 * The schedule's execution state.
 */
@property (nullable, nonatomic, strong) NSNumber *executionState;

/**
 * The schedule's execution state change date.
 */
@property (nullable, nonatomic, strong, readonly) NSDate *executionStateChangeDate;

/**
 * The delayed execution date. This delay date takes precedent over the delay in seconds.
 */
@property (nullable, nonatomic, strong) NSDate *delayedExecutionDate;

/**
 * The schedule's edit grace period in seconds.
 */
@property(nullable, nonatomic, strong) NSNumber *editGracePeriod;

/**
 * The schedule's interval in seconds.
 */
@property(nullable, nonatomic, strong) NSNumber *interval;

/**
 * The trigger context.
 */
@property (nullable, nonatomic, strong) UAScheduleTriggerContext *triggerContext;

/**
 * The schedule type.
 */
@property (nullable, nonatomic, strong) NSNumber *type;

/**
 * The audience payload.
 */
@property (nullable, nonatomic, copy) NSString *audience;

/**
 * The campaigns info.
 */
@property (nullable, nonatomic, copy) NSDictionary *campaigns;

/**
 * The reporting context.
 */
@property (nullable, nonatomic, copy) NSDictionary *reportingContext;

/**
 * The frequency constraint IDs.
 */
@property (nullable, nonatomic, copy) NSArray<NSString *> *frequencyConstraintIDs;

/**
 * Whether the schedule has exceeded its limit.
 */
- (BOOL)isOverLimit;

/**
 * Whether the schedule has expired.
 */
- (BOOL)isExpired;

/**
 * Verifies the state. Logs a message if state is invalid.
 * @param state The state to check.
 * @returns `YES` if state matches, otherwise `NO`
 */
- (BOOL)verifyState:(UAScheduleState)state;

/**
 * Checks the state.
 * @param state The state to check.
 * @returns `YES` if state matches, otherwise `NO`
 */
- (BOOL)checkState:(UAScheduleState)state;

/**
 * Updates the state.
 * @param state The state.
 */
- (void)updateState:(UAScheduleState)state;

@end

NS_ASSUME_NONNULL_END
