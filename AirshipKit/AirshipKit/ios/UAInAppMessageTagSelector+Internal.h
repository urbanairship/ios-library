/* Copyright 2018 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessageTagSelector.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents the possible error conditions when deserializing tag selector from JSON.
 */
typedef NS_ENUM(NSInteger, UAInAppMessageTagSelectorErrorCode) {
    /**
     * Indicates an error with the tag selector JSON definition.
     */
    UAInAppMessageTagSelectorErrorCodeInvalidJSON,
};

/**
 * Model object for an in-app message audience constraint's tag selector.
 */
@interface UAInAppMessageTagSelector()

/**
 * Parses a json value for a tag selector.
 *
 * @param json The json value.
 * @param error An NSError pointer for storing errors, if applicable.
 * @return The parsed tag selector.
 */
+ (nullable instancetype)selectorWithJSON:(NSDictionary *)json error:(NSError **)error;

/**
 * Convert a tag selector back to JSON
 *
 * @return JSON NSDictionary
 */
- (NSDictionary *)toJSON;


@end

NS_ASSUME_NONNULL_END

