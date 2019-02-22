/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAScheduleEdits.h"
#import "UAInAppMessage.h"

NS_ASSUME_NONNULL_BEGIN


/**
 * Builder class for UAInAppMessageScheduleEdits.
 */
@interface UAInAppMessageScheduleEditsBuilder : UAScheduleEditsBuilder

///---------------------------------------------------------------------------------------
/// @name In App Message Schedule Edits Builder Properties
///---------------------------------------------------------------------------------------

/**
 * Message to display when schedule is triggered.
 */
@property(nonatomic, strong, nullable) UAInAppMessage *message;

@end

/**
 * Defines edits for an existing in-app message.
 */
@interface UAInAppMessageScheduleEdits : UAScheduleEdits

///---------------------------------------------------------------------------------------
/// @name In App Message Schedule Edits Properties
///---------------------------------------------------------------------------------------

/**
 * Message to display when schedule is triggered.
 */
@property(nonatomic, strong, nullable) UAInAppMessage *message;

/**
 * Creates an in-app message schedule edits with a builder block.
 *
 * @return The in-app message schedule edits.
 */
+ (instancetype)editsWithBuilderBlock:(void(^)(UAInAppMessageScheduleEditsBuilder *builder))builderBlock;


@end

NS_ASSUME_NONNULL_END

