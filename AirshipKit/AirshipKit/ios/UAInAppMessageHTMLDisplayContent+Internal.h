/* Copyright Urban Airship and Contributors */

#import "UAInAppMessageHTMLDisplayContent.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents the possible error conditions when deserializing display content from JSON.
 */
typedef NS_ENUM(NSInteger, UAInAppMessageHTMLDisplayContentErrorCode) {
    /**
     * Indicates an error with the display content info JSON definition.
     */
    UAInAppMessageHTMLDisplayContentErrorCodeInvalidJSON,
};

@interface UAInAppMessageHTMLDisplayContent ()

/**
 * Factory method for building HTML display content with JSON.
 *
 * @param json The json object.
 * @param error The optional error.
 *
 * @returns the display content if the json was able to be applied, otherwise nil.
 */
+ (nullable instancetype)displayContentWithJSON:(id)json error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END

