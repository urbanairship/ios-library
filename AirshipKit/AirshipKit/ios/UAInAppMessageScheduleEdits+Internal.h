/* Copyright Urban Airship and Contributors */

#import "UAInAppMessageScheduleEdits.h"

NS_ASSUME_NONNULL_BEGIN

@interface UAInAppMessageScheduleEdits ()

/**
 * Factory method to create an in-app message schedule edits instance from a JSON payload.
 *
 * @param json The JSON payload.
 * @param error An NSError pointer for storing errors, if applicable.
 * @return An in-app message schedule edits or `nil` if the JSON is invalid.
 */
+ (nullable instancetype)editsWithJSON:(id)json error:(NSError * _Nullable *)error;

@end

NS_ASSUME_NONNULL_END


