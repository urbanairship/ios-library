/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UATagGroups.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Protocol used to provide tag group history to external modules.
 * @note For internal use only. :nodoc:
 */
@protocol UATagGroupsHistory <NSObject>

@required

/**
 * The maximum age for stored sent mutations. Mutations older than this time interval will
 * be periodically purged.
 *
 * If unset, defaults to one day. Subsequent changes are locally persisted.
 */
@property (nonatomic, assign) NSTimeInterval maxSentMutationAge;

/**
 * Applies local history to the provided tag groups data, ignoring sent mutations
 * older than the provided maximum age in seconds.
 *
 * @param tagGroups A collection of tag groups.
 * @param maxAge The maximum age of locally stored sent mutations to consider. Older sent mutations
 * will not be applied.
 * @return Tag groups with history applied.
 */
- (UATagGroups *)applyHistory:(UATagGroups *)tagGroups maxAge:(NSTimeInterval)maxAge;

@end

NS_ASSUME_NONNULL_END

