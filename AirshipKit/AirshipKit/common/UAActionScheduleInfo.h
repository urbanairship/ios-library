/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAScheduleInfo.h"

NS_ASSUME_NONNULL_BEGIN


/**
 * JSON key for the schedule's actions.
 */
extern NSString *const UAActionScheduleInfoActionsKey;


/**
 * Builder class for a UAActionScheduleInfo.
 */
@interface UAActionScheduleInfoBuilder : UAScheduleInfoBuilder

///---------------------------------------------------------------------------------------
/// @name Action Schedule Info Builder Properties
///---------------------------------------------------------------------------------------

/**
 * Actions payload to run when the schedule is triggered.
 */
@property(nonatomic, copy, nullable) NSDictionary *actions;

/**
 * The schedule's group.
 */
@property(nonatomic, copy, nullable) NSString *group;

@end

/**
 * Defines the scheduled action.
 */
@interface UAActionScheduleInfo : UAScheduleInfo

///---------------------------------------------------------------------------------------
/// @name Action Schedule Info Properties
///---------------------------------------------------------------------------------------

/**
 * Actions payload to run when the schedule is triggered.
 */
@property(nonatomic, readonly) NSDictionary *actions;

@property(nonatomic, readonly, nullable) NSString *group;


///---------------------------------------------------------------------------------------
/// @name Action Schedule Info Factories
///---------------------------------------------------------------------------------------

/**
 * Factory method to create an action schedule info from a JSON payload.
 *
 * @param json The JSON payload.
 * @param error An NSError pointer for storing errors, if applicable.
 * @return An action schedule info or `nil` if the JSON is invalid.
 */
+ (nullable instancetype)actionScheduleInfoWithJSON:(id)json error:(NSError * _Nullable *)error;

/**
 * Creates an action schedule info with a builder block.
 *
 * @return The action schedule info.
 */
+ (instancetype)actionScheduleInfoWithBuilderBlock:(void(^)(UAActionScheduleInfoBuilder *builder))builderBlock;


@end

NS_ASSUME_NONNULL_END


