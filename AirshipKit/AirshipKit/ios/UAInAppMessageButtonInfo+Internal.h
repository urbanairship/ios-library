/* Copyright Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UAInAppMessageButtonInfo.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents the possible error conditions when deserializing button info from JSON.
 */
typedef NS_ENUM(NSInteger, UAButtonInfoErrorCode) {
    /**
     * Indicates an error with the button info JSON definition.
     */
    UAInAppMessageButtonInfoErrorCodeInvalidJSON,
};

/**
 * Defines an in-app message button.
 */
@interface UAInAppMessageButtonInfo()


/**
 * Factory method to create an in-app message button info from a JSON payload.
 *
 * @param json The JSON payload.
 * @param error An NSError pointer for storing errors, if applicable.
 * @return An in-app message button info or `nil` if the JSON is invalid.
 */
+ (nullable instancetype)buttonInfoWithJSON:(id)json error:(NSError * _Nullable *)error;

/**
 * Method to return the button info as its JSON representation.
 *
 * @returns JSON representation of the button info.
 */
- (NSDictionary *)toJSON;

@end

NS_ASSUME_NONNULL_END


