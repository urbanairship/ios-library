/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Convenience wrapper around sets of tag groups with common operations.
 */
@interface UATagGroups : NSObject <NSCoding>

/**
 * The raw tags, as a map of group IDs and tag sets.
 */
@property(nonatomic, readonly) NSDictionary *tags;

/**
 * UATagGroups class factory method.
 *
 * @param tags A dictionary of tag groups mapping group identifiers
 * to sets or arrays of tags. In the case of tag arrays, as found in JSON,
 * these will be normalized to sets.
 */
+ (instancetype)tagGroupsWithTags:(NSDictionary *)tags;

/**
 * Indicates whether the receiver contains all tags in the provided
 * tag groups instance.
 *
 * @param tagGroups An instance of UATagGroups
 * @return `YES` if the receiver contains all the tags, `NO` otherwise.
 */
- (BOOL)containsAllTags:(UATagGroups *)tagGroups;

/**
 * Indicates whether the receiver contains only device tags.
 *
 * @return `YES` if the receiver contains only device tags, `NO` otherwise.
 */
- (BOOL)containsOnlyDeviceTags;

/**
 * Produces the intersection of two tag groups.
 *
 * @param tagGroups The tag groups to intersect with the receiver.
 * @return The intersection.
 */
- (UATagGroups *)intersect:(UATagGroups *)tagGroups;

/**
 * Merges the responder with another collection of tag groups.
 *
 * @param tagGroups The tag groups to merge into the responder.
 * @return The merged tag groups.
 */
- (UATagGroups *)merge:(UATagGroups *)tagGroups;

/**
 * Converts the tags to a JSON-compatible dictionary.
 */
- (NSDictionary *)toJSON;

@end

NS_ASSUME_NONNULL_END
