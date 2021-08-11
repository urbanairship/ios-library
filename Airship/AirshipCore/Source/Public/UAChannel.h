/* Copyright Airship and Contributors */

#import "UAComponent.h"
#import "UAChannelNotificationCenterEvents.h"

@class UASubscriptionListEditor;
@class UAAttributesEditor;
@class UATagGroupsEditor;
@class UADisposable;
@class UAAttributeMutations;
@class UATagGroupUpdate;
@class UAAttributeUpdate;

NS_ASSUME_NONNULL_BEGIN

//---------------------------------------------------------------------------------------
// UAChannel Class
//---------------------------------------------------------------------------------------

/**
 * Notification posted when a channel is created.
 * @note For internal use only. :nodoc:
 */
extern NSNotificationName const UAChannelCreatedEvent;

/**
 * Notification posted when a channel audience is updated.
 * @note For internal use only. :nodoc:
 */
extern NSNotificationName const UAChannelAudienceUpdatedEvent;

/**
 * Tag group updates key in the `UAChannelAudienceUpdatedEvent` event.
 * @note For internal use only. :nodoc:
 */
extern NSString *const UAChannelAudienceUpdatedEventTagsKey;

/**
 * Attribute updates key in the `UAChannelAudienceUpdatedEvent` event.
 * @note For internal use only. :nodoc:
 */
extern NSString *const UAChannelAudienceUpdatedEventAttributesKey;

/**bu
* This singleton provides an interface to the channel functionality provided by the Airship iOS Push API.
*/
@interface UAChannel : UAComponent

/**
 The Channel ID.
 */
@property(nullable, nonatomic, readonly) NSString *identifier;

/**
 * Returns the pending tag groups updates.
 * @note For internal use only. :nodoc:
 */
@property (nonatomic, readonly) NSArray<UATagGroupUpdate *> *pendingTagGroupUpdates;

/**
 * Returns the pending attribute updates.
 * @note For internal use only. :nodoc:
 */
@property (nonatomic, readonly) NSArray<UAAttributeUpdate *> *pendingAttributeUpdates;

/**
 Tags for this device.
 */
@property (nonatomic, copy) NSArray<NSString *> *tags;

/**
 * Allows setting tags from the device. Tags can be set from either the server or the device, but
 * not both (without synchronizing the data), so use this flag to explicitly enable or disable
 * the device-side flags.
 *
 * Set this to `NO` to prevent the device from sending any tag information to the server when using
 * server-side tagging. Defaults to `YES`.
 */
@property (nonatomic, assign, getter=isChannelTagRegistrationEnabled) BOOL channelTagRegistrationEnabled;

///---------------------------------------------------------------------------------------
/// @name Subscription lists
///---------------------------------------------------------------------------------------

/**
 * Creates a subscription list editor that can be used to edit the subscription lists on the channel.
 * @return A subscription list editor.
 */
- (UASubscriptionListEditor *)editSubscriptionLists;

/**
 * Fetches subscriptoin lists.
 * @param completionHandler The handler with the result. On error, caller should retry with exponetial backoff.
 * @return A disposable to cancel the request.
 */
- (UADisposable *)fetchSubscriptionListsWithCompletionHandler:(void(^)(NSArray<NSString *> * _Nullable listIDs, NSError * _Nullable error)) completionHandler;

///---------------------------------------------------------------------------------------
/// @name Tags
///---------------------------------------------------------------------------------------

/**
 * Adds a tag to the list of tags for the device. To update the server, make all of your changes, then call
 * `updateRegistration` to update the Airship server.
 *
 * @note When updating multiple server-side values (tags, alias, time zone, quiet time), set the
 * values first, then call `updateRegistration`. Batching these calls improves performance.
 *
 * @param tag Tag to be added
 */
- (void)addTag:(NSString *)tag;

/**
 * Adds a collection of tags to the current list of device tags. To update the server, make all of your
 * changes, then call `updateRegistration`.
 *
 * @note When updating multiple server-side values (tags, alias, time zone, quiet time), set the
 * values first, then call `updateRegistration`. Batching these calls improves performance.
 *
 * @param tags Array of new tags
 */
- (void)addTags:(NSArray<NSString *> *)tags;

/**
 * Removes a tag from the current tag list. To update the server, make all of your changes, then call
 * `updateRegistration`.
 *
 * @note When updating multiple server-side values (tags, alias, time zone, quiet time), set the
 * values first, then call `updateRegistration`. Batching these calls improves performance.
 *
 * @param tag Tag to be removed
 */
- (void)removeTag:(NSString *)tag;

/**
 * Removes a collection of tags from a device. To update the server, make all of your changes, then call
 * `updateRegistration`.
 *
 * @note When updating multiple server-side values (tags, alias, time zone, quiet time), set the
 * values first, then call `updateRegistration`. Batching these calls improves performance.
 *
 * @param tags Array of tags to be removed
 */
- (void)removeTags:(NSArray<NSString *> *)tags;


///---------------------------------------------------------------------------------------
/// @name Tag Groups
///---------------------------------------------------------------------------------------

/**
 * Creates a tag group editor for the channel.
 * @return A tag group editor.
 */
- (UATagGroupsEditor *)editTagGroups;

/**
 * Add tags to channel tag groups. To update the server,
 * make all of your changes, then call `updateRegistration`.
 *
 * @param tags Array of tags to add.
 * @param tagGroupID Tag group ID string.
 * @deprecated Deprecated – to be removed in SDK version 16.0. Use  `editTagGroups`
 */
- (void)addTags:(NSArray<NSString *> *)tags group:(NSString *)tagGroupID __attribute__ ((deprecated));

/**
 * Removes tags from channel tag groups. To update the server,
 * make all of your changes, then call `updateRegistration`.
 *
 * @param tags Array of tags to remove.
 * @param tagGroupID Tag group ID string.
 * @deprecated Deprecated – to be removed in SDK version 16.0.  Use  `editTagGroups` instead.
 */
- (void)removeTags:(NSArray<NSString *> *)tags group:(NSString *)tagGroupID __attribute__ ((deprecated));

/**
 * Sets tags for channel tag groups. To update the server,
 * make all of your changes, then call `updateRegistration`.
 *
 * @param tags Array of tags to set.
 * @param tagGroupID Tag group ID string.
 * @deprecated Deprecated – to be removed in SDK version 16.0. Use  `editTagGroups` instead.
 */
- (void)setTags:(NSArray<NSString *> *)tags group:(NSString *)tagGroupID __attribute__ ((deprecated));


///---------------------------------------------------------------------------------------
/// @name Channel Attributes
///---------------------------------------------------------------------------------------

/**
 * Applies mutations to attributes associated with this device.
 *
 * @param mutations Attribute mutations to apply to this device.
 * @deprecated Deprecated – to be removed in SDK version 16.0. Use  `editAttributes` instead.
 */
- (void)applyAttributeMutations:(UAAttributeMutations *)mutations __attribute__ ((deprecated));

/**
 * Creates an attribute editor for the channel.
 * @return An attribute editor.
 */
- (UAAttributesEditor *)editAttributes;

///---------------------------------------------------------------------------------------
/// @name Channel Registration
///---------------------------------------------------------------------------------------

/**
 * Enables channel creation if channelCreationDelayEnabled was set to `YES` in the config.
 */
- (void)enableChannelCreation;

/**
 * Registers or updates the current registration with an API call. If push notifications are
 * not enabled, this unregisters the device token.
 *
 * Observe NSNotificationCenterEvents such as UAChannelCreatedEvent, UAChannelUpdatedEvent and UAChannelRegistrationFailedEvent
 * to receive success and failure callbacks.
 */
- (void)updateRegistration;

@end

NS_ASSUME_NONNULL_END
