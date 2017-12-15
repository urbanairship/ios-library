/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAScheduleInfo.h"
#import "UAInAppMessage.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * JSON key for the schedule's in-app message.
 */
extern NSString *const UAScheduleInfoInAppMessageKey;

/**
 * Builder class for a UAInAppMessageScheduleInfo.
 */
@interface UAInAppMessageScheduleInfoBuilder : UAScheduleInfoBuilder

///---------------------------------------------------------------------------------------
/// @name In App Message Schedule Info Builder Properties
///---------------------------------------------------------------------------------------

/**
 * Message to display when schedule is triggered.
 */
@property(nonatomic, strong, nullable) UAInAppMessage *message;

@end

/**
 * Defines the scheduled in-app message.
 */
@interface UAInAppMessageScheduleInfo : UAScheduleInfo

///---------------------------------------------------------------------------------------
/// @name In App Message Schedule Info Properties
///---------------------------------------------------------------------------------------

/**
 * Message to display when schedule is triggered.
 */
@property(nonatomic, strong, nullable) UAInAppMessage *message;

/**
 * Factory method to create an in-app message schedule info from a JSON payload.
 *
 * @param json The JSON payload.
 * @param error An NSError pointer for storing errors, if applicable.
 * @return An in-app message schedule info or `nil` if the JSON is invalid.
 */
+ (nullable instancetype)inAppMessageScheduleInfoWithJSON:(id)json error:(NSError * _Nullable *)error;

/**
 * Creates an in-app message schedule info with a builder block.
 *
 * @return The in-app message schedule info.
 */
+ (instancetype)inAppMessageScheduleInfoWithBuilderBlock:(void(^)(UAInAppMessageScheduleInfoBuilder *builder))builderBlock;

/**
 * Return the message id from a JSON payload.
 *
 * @param json The JSON payload.
 * @return The message id or `nil` if the JSON is invalid.
 */
+ (NSString *)parseMessageID:(id)json;

@end

NS_ASSUME_NONNULL_END
