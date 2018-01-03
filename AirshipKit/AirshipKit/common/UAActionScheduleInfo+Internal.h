/* Copyright 2017 Urban Airship and Contributors */

#import "UAActionScheduleInfo.h"

NS_ASSUME_NONNULL_BEGIN


@interface UAActionScheduleInfo()

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
+ (nullable instancetype)scheduleInfoWithJSON:(id)json error:(NSError * _Nullable *)error;

@end

NS_ASSUME_NONNULL_END




