/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class UATagGroupUpdate;

/**
 * Defines changes to perform on tag groups.
 * @note For internal use only. :nodoc:
 */
@interface UATagGroupsMutation : NSObject <NSSecureCoding>

/**
 * Factory method to define tags to be added to a tag group.
 * @param tags The tags to be added.
 * @param group The tag group.
 * @return The mutation.
 */
+ (instancetype)mutationToAddTags:(NSArray<NSString *> *)tags group:(NSString *)group;

/**
 * Factory method to define tags to be removed from a tag group.
 * @param tags The tags to be removed.
 * @param group The tag group.
 * @return The mutation.
 */
+ (instancetype)mutationToRemoveTags:(NSArray<NSString *> *)tags group:(NSString *)group;

/**
 * Factory method to define tags to be set to a tag group.
 * @param tags The tags to be set.
 * @param group The tag group.
 * @return The mutation.
 */
+ (instancetype)mutationToSetTags:(NSArray<NSString *> *)tags group:(NSString *)group;

/**
 * Collapses an array of tag group mutations to either 1 or 2 mutations.
 *
 * Set tags will always be in its own mutation.
 * Add and remove will try to collapse into a set if available.
 * Adds will be removed from any remove changes, and vice versa.
 *
 * @param mutations The mutations to collapse.
 * @return An array of collapsed mutations.
 */
+ (NSArray<UATagGroupsMutation *> *)collapseMutations:(NSArray<UATagGroupsMutation *> *)mutations;

/**
 * The mutation payload for `UATagGroupsAPIClient`.
 * @return A JSON safe dictionary to be used in a request body.
 */
- (NSDictionary *)payload;

- (NSArray<UATagGroupUpdate *> *)tagGroupUpdates;

@end

NS_ASSUME_NONNULL_END
