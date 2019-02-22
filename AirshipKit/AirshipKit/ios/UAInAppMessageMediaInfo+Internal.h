/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessageMediaInfo.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents the possible error conditions when deserializing media info from JSON.
 */
typedef NS_ENUM(NSInteger, UAMediaInfoErrorCode) {
    /**
     * Indicates an error with the media info JSON definition.
     */
    UAInAppMessageMediaInfoErrorCodeInvalidJSON,
};

/**
 * Defines in-app message media content.
 */
@interface UAInAppMessageMediaInfo()

/**
 * Factory method to create an in-app message media info from a JSON payload.
 *
 * @param json The JSON payload.
 * @param error An NSError pointer for storing errors, if applicable.
 * @return An in-app message media info or `nil` if the JSON is invalid.
 */
+ (nullable instancetype)mediaInfoWithJSON:(id)json error:(NSError * _Nullable *)error;


/**
 * Method to return the media as its JSON representation.
 *
 * @returns JSON representation of the media info.
 */
- (NSDictionary *)toJSON;

@end

NS_ASSUME_NONNULL_END


