/* Copyright Airship and Contributors */

#import "UAInAppMessageScheduleEdits.h"
#import "UAInAppMessage+Internal.h"

NS_ASSUME_NONNULL_BEGIN

@interface UAInAppMessageScheduleEditsBuilder ()

/**
 * Applies fields from a JSON object.
 *
 * @param json The json object.
 * @param source The source of the message.
 * @param error The optional error.
 * @returns `YES` if the json was able to be applied, otherwise `NO`.
 */
- (BOOL)applyFromJson:(id)json source:(UAInAppMessageSource)source error:(NSError * _Nullable *)error;

@end

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


