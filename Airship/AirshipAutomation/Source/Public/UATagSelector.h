/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Model object for an audience tag selector.
 */
NS_SWIFT_NAME(TagSelector)
@interface UATagSelector : NSObject

/**
 * Creates an AND tag selector.
 *
 * @param selectors An array of selectors to AND together.
 * @return The AND tag selector.
 */
+ (instancetype)and:(NSArray<UATagSelector *> *)selectors;

/**
 * Creates an OR tag selector.
 *
 * @param selectors An array of selectors to OR together.
 * @return The OR tag selector.
 */
+ (instancetype)or:(NSArray<UATagSelector *> *)selectors;

/**
 * Creates a NOT tag selector.
 *
 * @param selector A selector to apply NOT to.
 * @return The NOT tag selector.
 */
+ (instancetype)not:(UATagSelector *)selector;

/**
 * Creates a tag selector that checks for tag.
 *
 * @param tag The tag.
 * @return The tag selector.
 */
+ (instancetype)tag:(NSString *)tag;

/**
 * Applies the tag selector to an array of tags.
 *
 * @param tags The array of tags.
 * @return YES if the tag selector matches the tags, otherwise NO.
 */
- (BOOL)apply:(NSArray<NSString *> *)tags;

@end

NS_ASSUME_NONNULL_END
