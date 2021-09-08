/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class UAInAppMessage;
@class UAScheduleAudience;

/**
 * Builder class for UAScheduleEdits.
 */
NS_SWIFT_NAME(ScheduleEditsBuilder)
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
 * The schedule's interval. The amount of time to pause the schedule after executing.
 */
@property(nonatomic, strong, nullable) NSNumber *interval;

/**
 * The schedule's metadata.
 */
@property(nonatomic, copy, nullable) NSDictionary *metadata;


/**
 * The schedule's edit grace period. The amount of time the schedule will still be editable after it has expired
 * or finished executing.
 */
@property(nonatomic, strong) NSNumber *editGracePeriod;

/**
 * The audience conditions for the message.
 *
 * Optional.
 */
@property(nonatomic, strong, nullable) UAScheduleAudience *audience;


@end

/**
 * Schedule edits.
 */
NS_SWIFT_NAME(ScheduleEdits)
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
 * The schedule's metadata.
 */
@property(nonatomic, readonly, nullable) NSDictionary *metadata;

/**
 * The schedule's interval. The amount of time to pause the schedule after executing.
 */
@property(nonatomic, readonly, nullable) NSNumber *interval;


/**
 * The schedule's edit grace period. The amount of time the schedule will still be editable after it has expired
 * or finished executing.
 */
@property(nonatomic, readonly, nullable) NSNumber *editGracePeriod;

/**
 * The audience conditions for the message.
*/
@property(nonatomic, readonly, nullable) UAScheduleAudience *audience;

///---------------------------------------------------------------------------------------
/// @name Schedule Edit Methods
///---------------------------------------------------------------------------------------

/**
 * Creates edits that also updates the schedule's data as an in-app message.
 * @param message The message.
 * @param builderBlock The builder block.
 * @return The schedule edits.
 */
+ (instancetype)editsWithMessage:(UAInAppMessage *)message
                    builderBlock:(void(^)(UAScheduleEditsBuilder *builder))builderBlock;

/**
 * Creates edits that also updates the schedule's data as actions.
 * @param actions The actions.
 * @param builderBlock The builder block.
 * @return The schedule edits.
 */
+ (instancetype)editsWithActions:(NSDictionary *)actions
                    builderBlock:(void(^)(UAScheduleEditsBuilder *builder))builderBlock;

/**
 * Creates schedule edits.
 * @param builderBlock The builder block.
 * @return The schedule edits.
 */
+ (instancetype)editsWithBuilderBlock:(void(^)(UAScheduleEditsBuilder *builder))builderBlock;


@end

NS_ASSUME_NONNULL_END
