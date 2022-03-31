/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UATagSelector.h"
#import "UAAirshipAutomationCoreImport.h"
#import "UATagGroups+Internal.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents the possible error conditions when deserializing tag selector from JSON.
 */
typedef NS_ENUM(NSInteger, UATagSelectorErrorCode) {
    /**
     * Indicates an error with the tag selector JSON definition.
     */
    UATagSelectorErrorCodeInvalidJSON,
};

/**
 * Model object for an  audience constraint's tag selector.
 */
@interface UATagSelector()

/**
 * Parses a json value for a tag selector.
 *
 * @param json The json value.
 * @param error An NSError pointer for storing errors, if applicable.
 * @return The parsed tag selector.
 */
+ (nullable instancetype)selectorWithJSON:(NSDictionary *)json error:(NSError **)error;

/**
 * Factory method.
 *
 * @param tag The tag.
 * @return A tag selector instance.
 */
+ (instancetype)tag:(NSString *)tag;

/**
 * Convert a tag selector back to JSON
 *
 * @return JSON NSDictionary
 */
- (NSDictionary *)toJSON;

/**
 * Applies the tag selector to an array of tags.
 *
 * @param tags The array of tags.
 * @return YES if the tag selector matches the tags, otherwise NO.
 */
- (BOOL)apply:(NSArray<NSString *> *)tags;

@end

NS_ASSUME_NONNULL_END

