/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UATagGroups.h"
#import "UAChannel.h"
#import "UANamedUser.h"

NS_ASSUME_NONNULL_BEGIN

@interface UATagGroupHistorian : NSObject

/*
 * The maximum age for stored sent mutations. Mutations older than this time interval will
 * be periodically purged.
 *
 * If unset, defaults to one day. Subsequent changes are locally persisted.
 */
@property (nonatomic, assign) NSTimeInterval maxSentMutationAge;


/**
* UATagGroupHistorian initializer.
*
* @param channel The channel.
* @param namedUser The named user.
* @return The initialized tag group historian.
*/
- (instancetype)initTagGroupHistorianWithChannel:(UAChannel *)channel namedUser:(UANamedUser *)namedUser;
   
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
