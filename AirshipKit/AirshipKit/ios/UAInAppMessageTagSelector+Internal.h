/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessageTagSelector.h"
#import "UATagGroups+Internal.h"

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

@property (nonatomic, readonly) UATagGroups *tagGroups;

/**
 * Parses a json value for a tag selector.
 *
 * @param json The json value.
 * @param error An NSError pointer for storing errors, if applicable.
 * @return The parsed tag selector.
 */
+ (nullable instancetype)selectorWithJSON:(NSDictionary *)json error:(NSError **)error;

/**
 * UAInAppMessageTagSelector class factory
 *
 * @param tag The tag.
 */
+ (instancetype)tag:(NSString *)tag;

/**
 * UAInAppMessageTagSelector class factory
 *
 * @param tag The tag.
 * @param group The tag group.
 */
+ (instancetype)tag:(NSString *)tag group:(NSString *)group;

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
 * @param tagGroups The tag groups.
 * @return YES if the tag selector matches the tags, otherwise NO.
 */
- (BOOL)apply:(NSArray<NSString *> *)tags tagGroups:(nullable UATagGroups *)tagGroups;

/**
 * Indicates whether the tag selector contains tag groups.
 *
 * @return `YES` if the tag selector contains tag groups, `NO` otherwise.
 */
- (BOOL)containsTagGroups;

@end

NS_ASSUME_NONNULL_END

