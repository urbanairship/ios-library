/* Copyright Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UAInAppMessageTextInfo.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents the possible error conditions when deserializing text info from JSON.
 */
typedef NS_ENUM(NSInteger, UAInAppMessageTextInfoErrorCode) {
    /**
     * Indicates an error with the text info JSON definition.
     */
    UAInAppMessageTextInfoErrorCodeInvalidJSON,
};


/**
 * Defines the text that appears in an in-app message.
 */
@interface UAInAppMessageTextInfo()

/**
 * Factory method to create an in-app message text info from a JSON dictionary.
 *
 * @param json The JSON dictionary.
 * @param error An NSError pointer for storing errors, if applicable.
 * @return An in-app message text info or `nil` if the JSON is invalid.
 */
+ (nullable instancetype)textInfoWithJSON:(id)json error:(NSError * _Nullable *)error;

/**
 * Method to return the text info as its JSON representation.
 *
 * @returns JSON representation of the text info.
 */
- (NSDictionary *)toJSON;

@end

NS_ASSUME_NONNULL_END


