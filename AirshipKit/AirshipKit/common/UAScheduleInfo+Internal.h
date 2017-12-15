/* Copyright 2017 Urban Airship and Contributors */

#import "UAScheduleInfo.h"

NS_ASSUME_NONNULL_BEGIN

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
@property(nonatomic, copy) NSArray *triggers;

/**
 * Schedule's limit.
 */
@property(nonatomic, assign) NSUInteger limit;

/**
 * Schedule's start time.
 */
@property(nonatomic, strong) NSDate *start;

/**
 * Schedule's end time.
 */
@property(nonatomic, strong) NSDate *end;

/**
 * Schedule's delay.
 */
@property(nonatomic, strong, nullable) UAScheduleDelay *delay;

/**
 * The schedule's group.
 */
@property(nonatomic, copy, nullable) NSString *group;

/**
 * Default init method.
 *
 * @param builder The schedule info builder.
 * @return The initialized instance.
 */
- (instancetype)initWithBuilder:(UAScheduleInfoBuilder *)builder;

@end

/**
 * Builder class for a UAScheduleInfo.
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

