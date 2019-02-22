/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAScheduleInfo.h"
#import "UAInAppMessage.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * JSON key for the schedule's in-app message.
 */
extern NSString *const UAScheduleInfoInAppMessageKey;

/**
 * Builder class for UAInAppMessageScheduleInfo.
 */
@interface UAInAppMessageScheduleInfoBuilder : UAScheduleInfoBuilder

///---------------------------------------------------------------------------------------
/// @name In App Message Schedule Info Builder Properties
///---------------------------------------------------------------------------------------

/**
 * Message to display when schedule is triggered.
 *
 * Required.
 */
@property(nonatomic, strong, nullable) UAInAppMessage *message;

@end

/**
 * Defines the schedule and content for an in-app message.
 *
 * @note This object is built using `UAInAppMessageScheduleInfoBuilder`.
 */
@interface UAInAppMessageScheduleInfo : UAScheduleInfo

///---------------------------------------------------------------------------------------
/// @name In App Message Schedule Info Properties
///---------------------------------------------------------------------------------------

/**
 * Message to display when schedule is triggered.
 */
@property(nonatomic, readonly) UAInAppMessage *message;

/**
 * Creates an in-app message schedule info with a builder block.
 */
+ (nullable instancetype)scheduleInfoWithBuilderBlock:(void(^)(UAInAppMessageScheduleInfoBuilder *builder))builderBlock;

/**
 * Return the message id from a JSON payload.
 *
 * @param json The JSON payload.
 * @return The message id or `nil` if the JSON is invalid.
 */
+ (nullable NSString *)parseMessageID:(id)json;

@end

NS_ASSUME_NONNULL_END
