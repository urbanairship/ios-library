/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessageResolution.h"
#import "UAInAppMessageButtonInfo+Internal.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents the possible error conditions when deserializing button info from JSON.
 */
typedef NS_ENUM(NSInteger, UAInAppMessageResolutionErrorCode) {
    /**
     * Indicates an error with the message resolution JSON definition.
     */
    UAInAppMessageResolutionErrorCodeInvalidJSON,
};

/**
 * In-app message resolution info.
 */
@interface UAInAppMessageResolution ()

/**
 * Factory method to create an in-app message resolution from a JSON payload.
 *
 * @param json The JSON payload.
 * @param error An NSError pointer for storing errors, if applicable.
 * @return A message resolution or `nil` if the JSON is invalid.
 */
+ (nullable instancetype)resolutionWithJSON:(id)json error:(NSError * _Nullable *)error;

/**
 * Method to return the message resolution as its JSON representation.
 *
 * @returns JSON representation of the message resolution.
 */
- (NSDictionary *)toJSON;

@end

NS_ASSUME_NONNULL_END
