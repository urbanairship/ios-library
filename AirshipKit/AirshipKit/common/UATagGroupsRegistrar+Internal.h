/* Copyright 2018 Urban Airship and Contributors */

#import <Foundation/Foundation.h>

#import "UAConfig.h"
#import "UATagGroupsAPIClient+Internal.h"
#import "UAComponent+Internal.h"
#import "UAPreferenceDataStore+Internal.h"

NS_ASSUME_NONNULL_BEGIN

@interface UATagGroupsRegistrar : UAComponent

///---------------------------------------------------------------------------------------
/// @name Tag Groups Registrar Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method to create a channel tag groups registrar.
 * @param config The Urban Airship config.
 * @param dataStore The shared preference data store.
 * @return A new tag groups registrar instance.
 */
+ (instancetype)channelTagGroupsRegistrarWithConfig:(UAConfig *)config dataStore:(UAPreferenceDataStore *)dataStore;

/**
 * Factory method to create a channel tag groups registrar. Used for testing.
 * @param dataStore The shared preference data store.
 * @param apiClient The internal tag groups API client.
 * @param operationQueue An NSOperation queue used to synchronize changes to tag groups.
 * @return A new tag groups registrar instance.
 */
+ (instancetype)channelTagGroupsRegistrarWithDataStore:(UAPreferenceDataStore *)dataStore apiClient:(UATagGroupsAPIClient *)apiClient operationQueue:(NSOperationQueue *)operationQueue;

/**
 * Factory method to create a named user tag groups registrar.
 * @param config The Urban Airship config.
 * @param dataStore The shared preference data store.
 * @return A new tag groups registrar instance.
 */
+ (instancetype)namedUserTagGroupsRegistrarWithConfig:(UAConfig *)config dataStore:(UAPreferenceDataStore *)dataStore;

/**
 * Factory method to create a named user tag groups registrar. Used for testing.
 * @param dataStore The shared preference data store.
 * @param apiClient The internal tag groups API client.
 * @param operationQueue An NSOperation queue used to synchronize changes to tag groups.
 * @return A new tag groups registrar instance.
 */
+ (instancetype)namedUserTagGroupsRegistrarWithDataStore:(UAPreferenceDataStore *)dataStore apiClient:(UATagGroupsAPIClient *)apiClient operationQueue:(NSOperationQueue *)operationQueue;

/**
 * Update the tag groups for the given identifier.
 * @param channelID The channel identifier.
 */
- (void)updateTagGroupsForID:(NSString *)channelID;

/**
 * Add tags to a tag group. To update the server, make all of your changes,
 * then call `updateChannelTagGroupsForChannelID:`.
 *
 * @param tags Array of tags to add.
 * @param tagGroupID Tag group ID string.
 */
- (void)addTags:(NSArray *)tags group:(NSString *)tagGroupID;

/**
 * Remove tags from a tag group. To update the server, make all of your changes,
 * then call `updateChannelTagGroupsForChannelID`.
 *
 * @param tags Array of tags to remove.
 * @param tagGroupID Tag group ID string.
 */
- (void)removeTags:(NSArray *)tags group:(NSString *)tagGroupID;

/**
 * Set tags for a tag group. To update the server, make all of your changes,
 * then call `updateChannelTagGroupsForChannelID`.
 *
 * @param tags Array of tags to set.
 * @param tagGroupID Tag group ID string.
 */
- (void)setTags:(NSArray *)tags group:(NSString *)tagGroupID;

/**
 * Clears all pending tag updates.
 */
- (void)clearAllPendingTagUpdates;

@end

NS_ASSUME_NONNULL_END
