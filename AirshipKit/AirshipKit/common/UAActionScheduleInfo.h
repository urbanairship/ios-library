/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAScheduleInfo.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * JSON key for the schedule's actions.
 */
extern NSString *const UAActionScheduleInfoActionsKey;

/**
 * Builder class for UAActionScheduleInfo.
 */
@interface UAActionScheduleInfoBuilder : UAScheduleInfoBuilder

///---------------------------------------------------------------------------------------
/// @name Action Schedule Info Builder Properties
///---------------------------------------------------------------------------------------

/**
 * The schedule's group.
 */
@property(nonatomic, copy, nullable) NSString *group;

/**
 * Actions payload to run when the schedule is triggered.
 */
@property(nonatomic, strong, nullable) NSDictionary *actions;

@end

/**
 * Defines the scheduled action.
 */
@interface UAActionScheduleInfo : UAScheduleInfo

///---------------------------------------------------------------------------------------
/// @name Action Schedule Info Properties
///---------------------------------------------------------------------------------------

/**
 * The schedule's group.
 */
@property(nonatomic, readonly, nullable) NSString *group;

/**
 * Actions payload to run when the schedule is triggered.
 */
@property(nonatomic, readonly, nullable) NSDictionary *actions;

///---------------------------------------------------------------------------------------
/// @name Action Schedule Info Factories
///---------------------------------------------------------------------------------------

/**
 * Creates an action schedule info with a builder block.
 *
 * @return The action schedule info.
 */
+ (instancetype)scheduleInfoWithBuilderBlock:(void(^)(UAActionScheduleInfoBuilder *builder))builderBlock;

/**
 * Factory method to create an action schedule info from a JSON payload.
 *
 * @param json The JSON payload.
 * @param error An NSError pointer for storing errors, if applicable.
 * @return An action schedule info or `nil` if the JSON is invalid.
 */
+ (nullable instancetype)scheduleInfoWithJSON:(id)json error:(NSError * _Nullable *)error;


@end

NS_ASSUME_NONNULL_END


