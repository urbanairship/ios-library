/* Copyright Urban Airship and Contributors */

#import "UAScheduleInfo.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents the possible error conditions when deserializing schedule info from JSON.
 */
typedef NS_ENUM(NSInteger, UAScheduleInfoErrorCode) {
    /**
     * Indicates an error with the schedule info JSON definition.
     */
    UAScheduleInfoErrorCodeInvalidJSON,
};

/**
 * The domain for NSErrors.
 */
extern NSString * const UAScheduleInfoErrorDomain;

/**
 * JSON key for the actions's priority.
 */
extern NSString *const UAScheduleInfoPriorityKey;

/**
 * JSON key for the schedule's limit.
 */
extern NSString *const UAScheduleInfoLimitKey;

/**
 * JSON key for the schedule's group.
 */
extern NSString *const UAScheduleInfoGroupKey;

/**
 * JSON key for the schedule's end.
 */
extern NSString *const UAScheduleInfoEndKey;

/**
 * JSON key for the schedule's start.
 */
extern NSString *const UAScheduleInfoStartKey;

/**
 * JSON key for the schedule's triggers.
 */
extern NSString *const UAScheduleInfoTriggersKey;

/**
 * JSON key for the schedule's delay.
 */
extern NSString *const UAScheduleInfoDelayKey;

/**
 * JSON key for the schedule's interval.
 */
extern NSString *const UAScheduleInfoIntervalKey;

/**
 * JSON key for the schedule's edit grace period.
 */
extern NSString *const UAScheduleInfoEditGracePeriodKey;

/*
 * SDK-private extensions to UAScheduleTrigger
 */
@interface UAScheduleInfo ()

/**
 * Schedule's data.
 */
@property(nonatomic, copy, nullable) NSString *data;

/**
 * Schedule's priority.
 */
@property(nonatomic, assign) NSInteger priority;

/**
 * Schedule's triggers.
 */
@property(nonatomic, strong) NSArray *triggers;

/**
 * Schedule's limit.
 */
@property(nonatomic, assign) NSUInteger limit;

/**
 * Schedule's start time.
 */
@property(nonatomic, strong, nullable) NSDate *start;

/**
 * Schedule's end time.
 */
@property(nonatomic, strong, nullable) NSDate *end;

/**
 * Schedule's delay.
 */
@property(nonatomic, strong, nullable) UAScheduleDelay *delay;

/**
 * The schedule's group.
 */
@property(nonatomic, copy, nullable) NSString *group;

/**
 * The schedule's edit grace period. The amount of time the schedule will still be editable after it has been expired
 * or finished executing.
 */
@property(nonatomic, assign) NSTimeInterval editGracePeriod;

/**
 * The schedule's interval. The amount of time to pause the schedule after executing.
 */
@property(nonatomic, assign) NSTimeInterval interval;


/**
 * Default init method.
 *
 * @param builder The schedule info builder.
 * @return The initialized instance.
 */
- (instancetype)initWithBuilder:(UAScheduleInfoBuilder *)builder;

@end

/**
 * Builder class for UAScheduleInfo.
 */
@interface UAScheduleInfoBuilder ()

/**
 * Applies fields from a JSON object.
 *
 * @param json The json object.
 * @param error The optional error.
 * @returns `YES` if the json was able to be applied, otherwise `NO`.
 */
- (BOOL)applyFromJson:(id)json error:(NSError * _Nullable *)error;

///---------------------------------------------------------------------------------------
/// @name Schedule Info Builder Properties
///---------------------------------------------------------------------------------------

/**
 * Schedule's data.
 */
@property(nonatomic, copy, nullable) NSString *data;

/**
 * The schedule's group.
 */
@property(nonatomic, copy, nullable) NSString *group;

@end

NS_ASSUME_NONNULL_END

