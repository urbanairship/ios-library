/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UATagGroupsMutation+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UATagGroupsTransactionRecord+Internal.h"
#import "UATagGroups.h"
#import "UATagGroupsHistory.h"
#import "UATagGroupsAPIClient+Internal.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents the local history of tag group mutations.
 */
@interface UAPendingTagGroupStore : NSObject<UATagGroupsHistory>

@property (nonatomic, copy) NSString *storeKey;

/**
 * UAPendingTagGroupStore class factory method.
 *
 * @param dataStore A preference data store to use for persistence.
 * @param storeKey The store key to use for persistence.
 */
+ (instancetype)historyWithDataStore:(UAPreferenceDataStore *)dataStore storeKey:(NSString *)storeKey;

/**
 * Returns all pending mutations, collapsing both channel and
 * named user tag group mutations into a single array.
 *
 * @return An array of tag group mutations.
 */
- (NSArray<UATagGroupsMutation *> *)pendingMutations;

/**
 * Returns all sent mutations, for both channel and named user
 * tag groups, which are newer than the provided maximum age in seconds.
 *
 * @return An array of tag group mutations.
 */
- (NSArray<UATagGroupsMutation *> *)sentMutationsWithMaxAge:(NSTimeInterval)maxAge;

/**
 * Adds a pending mutation.
 *
 * @param mutation The tag group mutation.
 */
- (void)addPendingMutation:(UATagGroupsMutation *)mutation;

/**
 * Adds a sent mutation.
 *
 * @param mutation The tag group mutation.
 * @param date The date the send was completed.
 */
- (void)addSentMutation:(UATagGroupsMutation *)mutation date:(NSDate *)date;

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

/**
 * Clears sent mutations.
 */
- (void)clearSentMutations;

/**
 * Clears all history.
 */
- (void)clearAll;


@end

NS_ASSUME_NONNULL_END
