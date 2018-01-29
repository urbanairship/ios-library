/* Copyright 2018 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAScheduleInfo.h"
#import "UAInAppMessage.h"

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

@end

NS_ASSUME_NONNULL_END

