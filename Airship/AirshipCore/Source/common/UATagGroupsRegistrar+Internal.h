/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

#import "UARuntimeConfig.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAPendingTagGroupStore+Internal.h"
#import "UATagGroupsAPIClient+Internal.h"
#import "UAComponent+Internal.h"
#import "UATagGroupsMutation+Internal.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Delegate protocol for tag groups registrar callbacks.
 */
@protocol UATagGroupsRegistrarDelegate <NSObject>
@required

/**
 * Called when a mutation has been successfully uploaded.
 *
 * @param mutation The mutation.
 * @param identifier The identifier associated with the mutation.
 */
- (void)uploadedTagGroupsMutation:(UATagGroupsMutation *)mutation
                       identifier:(NSString *)identifier;

@end

@interface UATagGroupsRegistrar : NSObject

/**
 * Whether the registrar is enabled. Defaults to `YES`.
 */
@property (nonatomic, assign) BOOL enabled;

/**
 * Pending tag groups mutations.
 */
@property (nonatomic, readonly) NSArray<UATagGroupsMutation *> *pendingMutations;

/**
 * The current identifier associated with this registrar.
 */
@property (nonatomic, readonly) NSString *identifier;

/**
 * The delegate to receive registrar callbacks.
 */
@property (nonatomic, weak) id<UATagGroupsRegistrarDelegate> delegate;

///---------------------------------------------------------------------------------------
/// @name Tag Groups Registrar Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method to create a tag groups registrar. Used for testing.
 * @param pendingTagGroupStore The pending tag group store.
 * @param apiClient The internal tag groups API client.
 * @param application The application.
 * @return A new tag groups registrar instance.
 */
+ (instancetype)tagGroupsRegistrarWithPendingTagGroupStore:(UAPendingTagGroupStore *)pendingTagGroupStore
                                                 apiClient:(UATagGroupsAPIClient *)apiClient
                                               application:(UIApplication *)application;

/**
 * Factory method to create a channel tag groups registrar.
 * @param config The runtime config.
 * @param dataStore The preference data store.
 * @return A new tag groups registrar instance.
 */
+ (instancetype)channelTagGroupsRegistrarWithConfig:(UARuntimeConfig *)config dataStore:(UAPreferenceDataStore *)dataStore;

/**
 * Factory method to create a named user tag groups registrar.
 * @param config The runtime config.
 * @param dataStore The preference data store.
 * @return A new tag groups registrar instance.
 */
+ (instancetype)namedUserTagGroupsRegistrarWithConfig:(UARuntimeConfig *)config dataStore:(UAPreferenceDataStore *)dataStore;

/**
 * Update the tag groups.
 */
- (void)updateTagGroups;

/**
 * Add tags to a tag group. To update the server, make all of your changes,
 * then call `updateTagGroupsForID:type:`.
 *
 * @param tags Array of tags to add.
 * @param tagGroupID Tag group ID string.
 */
- (void)addTags:(NSArray *)tags group:(NSString *)tagGroupID;

/**
 * Remove tags from a tag group. To update the server, make all of your changes,
 * then call `updateTagGroupsForID:type:`.
 *
 * @param tags Array of tags to remove.
 * @param tagGroupID Tag group ID string.
 */
- (void)removeTags:(NSArray *)tags group:(NSString *)tagGroupID;

/**
 * Set tags for a tag group. To update the server, make all of your changes,
 * then call `updateTagGroupsForID:type:`.
 *
 * @param tags Array of tags to set.
 * @param tagGroupID Tag group ID string.
 */
- (void)setTags:(NSArray *)tags group:(NSString *)tagGroupID;

/**
 * Clears pending mutations.
 */
- (void)clearPendingMutations;

/**
 * Sets the currently associated identifier.
 *
 * @param identifier The identifier.
 * @param clearPendingOnChange Whether pending mutations should be cleared if the identifier has changed.
 */
- (void)setIdentifier:(NSString *)identifier clearPendingOnChange:(BOOL)clearPendingOnChange;

@end

NS_ASSUME_NONNULL_END
