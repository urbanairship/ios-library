/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAScheduleDelay.h"
#import "UAScheduleTrigger.h"
#import "UAInAppMessage.h"
#import "UAScheduleAudience.h"

NS_ASSUME_NONNULL_BEGIN


/**
 * Max number of triggers a schedule can support.
 */
extern NSUInteger const UAScheduleMaxTriggers;


/**
 * Builder class for UASchedule.
 */
NS_SWIFT_NAME(ScheduleBuilder)
@interface UAScheduleBuilder : NSObject

///---------------------------------------------------------------------------------------
/// @name Schedule Builder Properties
///---------------------------------------------------------------------------------------

/**
 * The schedule's identifier.
 *
 * Optional. Most be unique. Defaults to a UUID.
 */
@property(nonatomic, copy) NSString *identifier;

/**
 * The schedule's metadata.
 *
 * Optional.
 */
@property(nonatomic, copy, nullable) NSDictionary *metadata;

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
 * The schedule's interval. The amount of time to pause the schedule after executing.
 *
 * Optional. Defaults to 0.
 */
@property(nonatomic, assign) NSTimeInterval interval;

/**
 * The schedule's group.
 *
 *  Optional.
 */
@property(nonatomic, copy, nullable) NSString *group;

/**
 * The schedule's edit grace period. The amount of time the schedule will still be editable after it has been expired
 * or finished executing.
 * Optional. Defaults to 0.
 */
@property(nonatomic, assign) NSTimeInterval editGracePeriod;

/**
 * The audience conditions for the message.
 *
 * Optional.
 */
@property(nonatomic, strong, nullable) UAScheduleAudience *audience;

@end


/**
 * Contains the schedule info and identifier.
 *
 * @note This object is built using `UAScheduleBuilder`.
 */
@interface UASchedule : NSObject

///---------------------------------------------------------------------------------------
/// @name Schedule Properties
///---------------------------------------------------------------------------------------

/**
 * The schedule's identifier.
 */
@property(nonatomic, readonly) NSString *identifier;

/**
 * The schedule's group.
 */
@property(nonatomic, readonly) NSString *group;

/**
 * The schedule's metadata.
 */
@property(nonatomic, readonly) NSDictionary *metadata;

/**
 * The schedule's priority. Schedules are executed by priority in ascending order.
 */
@property(nonatomic, readonly) NSInteger priority;

/**
 * Array of triggers. Triggers define conditions on when to execute the schedule.
 */
@property(nonatomic, readonly) NSArray<UAScheduleTrigger *> *triggers;

/**
 * The audience conditions for the message.
 */
@property(nonatomic, nullable, readonly) UAScheduleAudience *audience;

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
 * contains between 1 to 10 triggers, a valid delay, data, an
 *  the end time must be after the start time.
 */
@property(nonatomic, readonly) BOOL isValid;

///---------------------------------------------------------------------------------------
/// @name Schedule Methods
///---------------------------------------------------------------------------------------

/**
 * Checks if the schedule is equal to another schedule.
 *
 * @param schedule The other schedule to compare against.
 * @return `YES` if the schedules are equal, otherwise `NO`.
 */
- (BOOL)isEqualToSchedule:(nullable UASchedule *)schedule;

@end

NS_ASSUME_NONNULL_END
