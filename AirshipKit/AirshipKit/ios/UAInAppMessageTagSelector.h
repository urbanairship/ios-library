/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>

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
 * Model object for an In App Message audience constraint's tag selector.
 */
@interface UAInAppMessageTagSelector : NSObject

/**
 * Creates an AND tag selector.
 *
 * @param selectors An array of selectors to AND together.
 * @return The AND tag selector.
 */
+ (instancetype)and:(NSArray<UAInAppMessageTagSelector *> *)selectors;

/**
 * Creates an OR tag selector.
 *
 * @param selectors An array of selectors to OR together.
 * @return The OR tag selector.
 */
+ (instancetype)or:(NSArray<UAInAppMessageTagSelector *> *)selectors;

/**
 * Creates a NOT tag selector.
 *
 * @param selector A selector to apply NOT to.
 * @return The NOT tag selector.
 */
+ (instancetype)not:(UAInAppMessageTagSelector *)selector;

/**
 * Creates a tag selector that checks for tag.
 *
 * @param tag The tag.
 * @return The tag selector.
 */
+ (instancetype)tag:(NSString *)tag;

/**
 * Parses a json value for a tag selector.
 *
 * @param json The json value.
 * @param error An NSError pointer for storing errors, if applicable.
 * @return The parsed tag selector.
 */
+ (instancetype)parseJson:(NSDictionary *)json error:(NSError **)error;

/**
 * Convert a tag selector back to JSON
 *
 * @return JSON NSDictionary
 */
- (NSDictionary *)toJsonValue;

/**
 * Applies the tag selector to an array of tags.
 *
 * @param tags The array of tags.
 * @return YES if the tag selector matches the tags, otherwise NO.
 */
- (BOOL)apply:(NSArray<NSString *> *)tags;

@end

NS_ASSUME_NONNULL_END
