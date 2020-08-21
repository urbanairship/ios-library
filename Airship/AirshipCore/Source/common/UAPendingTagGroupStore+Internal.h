/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UATagGroupsMutation+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UATagGroupsTransactionRecord+Internal.h"
#import "UATagGroups.h"
#import "UATagGroupsAPIClient+Internal.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents the local history of tag group mutations.
 */
@interface UAPendingTagGroupStore : NSObject

/**
 * The datastore key.
 */
@property (nonatomic, readonly) NSString *storeKey;

/**
 * UAPendingTagGroupStore class factory method.
 *
 * @param dataStore A preference data store to use for persistence.
 */
+ (instancetype)channelHistoryWithDataStore:(UAPreferenceDataStore *)dataStore;

/**
 * UAPendingTagGroupStore class factory method.
 *
 * @param dataStore A preference data store to use for persistence.
 */
+ (instancetype)namedUserHistoryWithDataStore:(UAPreferenceDataStore *)dataStore;

/**
 * Returns all pending mutations, collapsing both channel and
 * named user tag group mutations into a single array.
 *
 * @return An array of tag group mutations.
 */
- (NSArray<UATagGroupsMutation *> *)pendingMutations;

/**
 * Adds a pending mutation.
 *
 * @param mutation The tag group mutation.
 */
- (void)addPendingMutation:(UATagGroupsMutation *)mutation;

/**
 * Peeks the top-most pending mutation from the queue corresponding to
 * the tag group type under consideration.
 *
 */
- (UATagGroupsMutation *)peekPendingMutation;

/**
 * Pops the top-most pending mutation from the queue corresponding to
 * the provided tag groups type.
 *
 */
- (UATagGroupsMutation *)popPendingMutation;

/**
 * Collapses pending mutations for the provided tag groups type.
 */
- (void)collapsePendingMutations;

/**
 * Clears pending mutations for the provided tag groups type.
 */
- (void)clearPendingMutations;

@end

NS_ASSUME_NONNULL_END
