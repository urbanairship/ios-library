/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAScheduleEdits.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Builder class for UAActionScheduleEdits.
 */
@interface UAActionScheduleEditsBuilder : UAScheduleEditsBuilder

///---------------------------------------------------------------------------------------
/// @name Action Schedule Edits Builder Properties
///---------------------------------------------------------------------------------------

/**
 * Actions payload to run when the schedule is triggered.
 */
@property(nonatomic, strong, nullable) NSDictionary *actions;

@end

/**
 * Defines the action schedule edits.
 */
@interface UAActionScheduleEdits : UAScheduleEdits

///---------------------------------------------------------------------------------------
/// @name Action Schedule Edits Properties
///---------------------------------------------------------------------------------------

/**
 * Actions payload to run when the schedule is triggered.
 */
@property(nonatomic, readonly, nullable) NSDictionary *actions;

///---------------------------------------------------------------------------------------
/// @name Action Schedule Edits Factories
///---------------------------------------------------------------------------------------

/**
 * Creates an action schedule edits with a builder block.
 *
 * @return The action schedule edits.
 */
+ (instancetype)editsWithBuilderBlock:(void(^)(UAActionScheduleEditsBuilder *builder))builderBlock;


@end

NS_ASSUME_NONNULL_END



