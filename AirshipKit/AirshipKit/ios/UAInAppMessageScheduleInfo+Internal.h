/* Copyright 2018 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAScheduleInfo.h"
#import "UAInAppMessageScheduleInfo.h"
#import "UAInAppMessage+Internal.h"

NS_ASSUME_NONNULL_BEGIN

@interface UAInAppMessageScheduleInfo ()

/**
 * Factory method to create an in-app message schedule info from a JSON payload.
 *
 * @param json The JSON payload.
 * @param error An NSError pointer for storing errors, if applicable.
 * @return An in-app message schedule info or `nil` if the JSON is invalid.
 */
+ (nullable instancetype)scheduleInfoWithJSON:(id)json error:(NSError * _Nullable *)error;

/**
 * Factory method to create an in-app message schedule info from a JSON payload.
 *
 * @param json The JSON payload.
 * @param defaultSource The in-app message source to use if one is not set in the JSON.
 * @return An in-app message schedule info or `nil` if the JSON is invalid.
 */
+ (nullable instancetype)scheduleInfoWithJSON:(id)json
                                defaultSource:(UAInAppMessageSource)defaultSource
                                        error:(NSError * _Nullable *)error;

@end

NS_ASSUME_NONNULL_END

