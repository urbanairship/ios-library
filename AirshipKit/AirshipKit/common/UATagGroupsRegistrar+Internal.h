/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>

#import "UAConfig.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UATagGroupsMutationHistory+Internal.h"
#import "UATagGroupsAPIClient+Internal.h"
#import "UAComponent+Internal.h"
#import "UATagGroupsType+Internal.h"

NS_ASSUME_NONNULL_BEGIN

@interface UATagGroupsRegistrar : UAComponent

///---------------------------------------------------------------------------------------
/// @name Tag Groups Registrar Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method to create a tag groups registrar.
 * @param config The Urban Airship config.
 * @param dataStore The shared data store.
 * @param mutationHistory The mutation history.
 * @return A new tag groups registrar instance.
 */
+ (instancetype)tagGroupsRegistrarWithConfig:(UAConfig *)config
                                   dataStore:(UAPreferenceDataStore *)dataStore
                             mutationHistory:(UATagGroupsMutationHistory *)mutationHistory;

/**
 * Factory method to create a tag groups registrar. Used for testing.
 * @param dataStore The shared data store.
 * @param mutationHistory The mutation history.
 * @param apiClient The internal tag groups API client.
 * @param operationQueue An NSOperation queue used to synchronize changes to tag groups.
 * @param application The application.
 * @return A new tag groups registrar instance.
 */
+ (instancetype)tagGroupsRegistrarWithDataStore:(UAPreferenceDataStore *)dataStore
                                mutationHistory:(UATagGroupsMutationHistory *)mutationHistory
                                      apiClient:(UATagGroupsAPIClient *)apiClient
                                 operationQueue:(NSOperationQueue *)operationQueue
                                    application:(UIApplication *)application;

/**
 * Update the tag groups for the given identifier.
 * @param channelID The channel identifier.
 * @param type The tag groups type.
 */
- (void)updateTagGroupsForID:(NSString *)channelID type:(UATagGroupsType)type;

/**
 * Add tags to a tag group. To update the server, make all of your changes,
 * then call `updateTagGroupsForID:type:`.
 *
 * @param tags Array of tags to add.
 * @param tagGroupID Tag group ID string.
 * @param type The tag groups type.
 */
- (void)addTags:(NSArray *)tags group:(NSString *)tagGroupID type:(UATagGroupsType)type;

/**
 * Remove tags from a tag group. To update the server, make all of your changes,
 * then call `updateTagGroupsForID:type:`.
 *
 * @param tags Array of tags to remove.
 * @param tagGroupID Tag group ID string.
 * @param type The tag groups type.
 */
- (void)removeTags:(NSArray *)tags group:(NSString *)tagGroupID type:(UATagGroupsType)type;

/**
 * Set tags for a tag group. To update the server, make all of your changes,
 * then call `updateTagGroupsForID:type:`.
 *
 * @param tags Array of tags to set.
 * @param tagGroupID Tag group ID string.
 * @param type The tag groups type.
 */
- (void)setTags:(NSArray *)tags group:(NSString *)tagGroupID type:(UATagGroupsType)type;

/**
 * Clears all pending tag updates.
 *
 * @param type The tag groups type.
 */
- (void)clearAllPendingTagUpdates:(UATagGroupsType)type;

@end

NS_ASSUME_NONNULL_END
