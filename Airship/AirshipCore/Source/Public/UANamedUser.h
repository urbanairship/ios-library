/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAComponent.h"
#import "UAAttributeMutations.h"
#import "UATagGroupsMutation.h"
#import "UAAttributePendingMutations.h"

@class UAPreferenceDataStore;

NS_ASSUME_NONNULL_BEGIN

/**
 * Notification posted when a named user tag group mutation is uploaded.
 *
 * User data will contain a UATagGroupsMutation, identifier string and NSDate under
 * UANamedUserUploadedAudienceMutationNotificationMutationKey,
 * UANamedUserUploadedAudienceMutationNotificationIdentifierKey, and
 * UANamedUserUploadedAudienceMutationNotificationDateKey, respectively.
 * @note For internal use only. :nodoc:
 */
extern NSString *const UANamedUserUploadedTagGroupMutationNotification;

/**
 * Notification posted when a named user attribute mutation is uploaded.
 *
 * User data will contain a UAAttributePendingMutations, identifier string and NSDate under
 * UANamedUserUploadedAudienceMutationNotificationMutationKey,
 * UANamedUserUploadedAudienceMutationNotificationIdentifierKey, and
 * UANamedUserUploadedAudienceMutationNotificationDateKey, respectively.
 * @note For internal use only. :nodoc:
 */
extern NSString *const UANamedUserUploadedAttributeMutationsNotification;

/**
 * The mutation key for UANamedUserUploadedTagGroupMutationNotification and UANamedUserUploadedAttributeMutationsNotification.
 * @note For internal use only. :nodoc:
 */
extern NSString *const UANamedUserUploadedAudienceMutationNotificationMutationKey;

/**
 * The identifier key for UANamedUserUploadedTagGroupMutationNotification and UANamedUserUploadedAttributeMutationsNotification.
 * @note For internal use only. :nodoc:
 */
extern NSString *const UANamedUserUploadedAudienceMutationNotificationIdentifierKey;

/**
 * The date key for UANamedUserUploadedTagGroupMutationNotification and UANamedUserUploadedAttributeMutationsNotification.
 * @note For internal use only. :nodoc:
 */
extern NSString *const UANamedUserUploadedAudienceMutationNotificationDateKey;

/**
 * Notification posted when the named user identifier changes.
 *
 * If an identifier is set, the user data will contain an identifier string under the key UANamedUserIdentifierChangedNotificationIdentifierKey .
 * @note For internal use only. :nodoc:
 */
extern NSString *const UANamedUserIdentifierChangedNotification;

/**
 * The identifier key for UANamedUserIdentifierChangedNotification.
 * @note For internal use only. :nodoc:
 */
extern NSString *const UANamedUserIdentifierChangedNotificationIdentifierKey;

/**
 * The named user is an alternate method of identifying the device. Once a named
 * user is associated to the device, it can be used to send push notifications
 * to the device.
 */
@interface UANamedUser : UAComponent

///---------------------------------------------------------------------------------------
/// @name Named User Properties
///---------------------------------------------------------------------------------------

/**
 * The named user ID for this device.
 */
@property (nonatomic, copy, nullable) NSString *identifier;

/**
 * Returns the pending tag groups mutuations.
 * @note For internal use only. :nodoc:
 */
@property (nonatomic, readonly)NSArray<UATagGroupsMutation *> *pendingTagGroups;

/**
 * Returns the pending attribute mutuations.
 * @note For internal use only. :nodoc:
 */
@property (nonatomic, readonly) UAAttributePendingMutations *pendingAttributes;

///---------------------------------------------------------------------------------------
/// @name Named User Management
///---------------------------------------------------------------------------------------

/**
 * Force updating the association or disassociation of the current named user ID.
 */
- (void)forceUpdate;

/**
 * Add tags to named user tags. To update the server,
 * make all of your changes, then call `updateTags`.
 *
 * @param tags Array of tags to add.
 * @param tagGroupID Tag group ID string.
 */
- (void)addTags:(NSArray<NSString *> *)tags group:(NSString *)tagGroupID;

/**
 * Removes tags from named user tags. To update the server,
 * make all of your changes, then call `updateTags`.
 *
 * @param tags Array of tags to remove.
 * @param tagGroupID Tag group ID string.
 */
- (void)removeTags:(NSArray<NSString *> *)tags group:(NSString *)tagGroupID;

/**
 * Set tags for named user tags. To update the server,
 * make all of your changes, then call `updateTags`.
 *
 * @param tags Array of tags to set.
 * @param tagGroupID Tag group ID string.
 */
- (void)setTags:(NSArray<NSString *> *)tags group:(NSString *)tagGroupID;

/**
 * Update named user tags.
 */
- (void)updateTags;

///---------------------------------------------------------------------------------------
/// @name Named User Attributes
///---------------------------------------------------------------------------------------

/**
 * Applies mutations to attributes associated with this named user.
 *
 * @param mutations Attribute mutations to apply to this named user.
 */
- (void)applyAttributeMutations:(UAAttributeMutations *)mutations;

@end

NS_ASSUME_NONNULL_END
