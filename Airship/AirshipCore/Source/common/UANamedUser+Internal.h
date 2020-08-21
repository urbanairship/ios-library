/* Copyright Airship and Contributors */

#import "UANamedUser.h"
#import "UAExtendableChannelRegistration.h"
#import "UATagGroupsMutation+Internal.h"
#import "UATagGroupsRegistrar+Internal.h"

@class UANamedUserAPIClient;
@class UARuntimeConfig;
@class UAAttributeRegistrar;
@class UAChannel;
@class UADate;

NS_ASSUME_NONNULL_BEGIN

/*
 * SDK-private extensions to UANamedUser
 */
@interface UANamedUser () <UATagGroupsRegistrarDelegate>

///---------------------------------------------------------------------------------------
/// @name Named User Internal Properties
///---------------------------------------------------------------------------------------

/**
 * Named user identifier data store key.
 */
extern NSString *const UANamedUserIDKey;

/**
 * Named user change token data store key.
 */
extern NSString *const UANamedUserChangeTokenKey;

/**
 * Named user last updated token data store key.
 */
extern NSString *const UANamedUserLastUpdatedTokenKey;

/**
 * Notification posted when a named user tag group mutation is uploaded.
 *
 * User data will contain a UATagGroupsMutation, identifier string and NSDate under
 * UANamedUserUploadedTagGroupMutationNotificationMutationKey,
 * UANamedUserUploadedTagGroupMutationNotificationIdentifierKey, and
 * UANamedUserUploadedTagGroupMutationNotificationDateKey, respectively.
 */
extern NSString *const UANamedUserUploadedTagGroupMutationNotification;

/**
 * The mutation key for UANamedUserUploadedTagGroupMutationNotification.
 */
extern NSString *const UANamedUserUploadedTagGroupMutationNotificationMutationKey;

/**
 * The identifier key for UANamedUserUploadedTagGroupMutationNotification.
 */
extern NSString *const UANamedUserUploadedTagGroupMutationNotificationIdentifierKey;

/**
 * The date key for UANamedUserUploadedTagGroupMutationNotification.
 */
extern NSString *const UANamedUserUploadedTagGroupMutationNotificationDateKey;

/**
 * The change token tracks the start of setting the named user ID.
 */
@property (nonatomic, copy, nullable) NSString *changeToken;

/**
 * The last updated token tracks when the named user ID was set successfully.
 */
@property (nonatomic, copy, nullable) NSString *lastUpdatedToken;

/**
 * The named user API client.
 */
@property (nonatomic, strong) UANamedUserAPIClient *namedUserAPIClient;

/**
 * The data store to save and load named user info.
 */
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;

/**
 * The push instance.
 */
@property (nonatomic, strong) UAChannel<UAExtendableChannelRegistration> *channel;

/**
 * The airship config.
 */
@property (nonatomic, strong) UARuntimeConfig *config;

///---------------------------------------------------------------------------------------
/// @name Named User Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method to create a named user. For testing.
 * @parm channel The UAChannel instance.
 * @param config The Airship config.
 * @param dataStore The shared preference data store.
 * @return A named user instance.
 */
+ (instancetype)namedUserWithChannel:(UAChannel *)channel
                              config:(UARuntimeConfig *)config
                           dataStore:(UAPreferenceDataStore *)dataStore;

/**
 * Factory method to create a named user. For testing.
 * @parm channel The UAChannel instance.
 * @param config The Airship config.
 * @param dataStore The shared preference data store.
 * @param tagGroupsRegistrar The tag groups registrar.
 * @param attributeRegistrar The attribute registrar
 * @param date The date for setting the timestamp.
 * @return A named user instance.
 */
+ (instancetype)namedUserWithChannel:(UAChannel *)channel
                              config:(UARuntimeConfig *)config
                           dataStore:(UAPreferenceDataStore *)dataStore
                  tagGroupsRegistrar:(UATagGroupsRegistrar *)tagGroupsRegistrar
                  attributeRegistrar:(UAAttributeRegistrar *)attributeRegistrar
                                date:(UADate *)date;

/**
 * Updates the association or disassociation of the current named user ID.
 */
- (void)update;

/**
 * Disassociate the named user only if the named user ID is really nil.
 */
- (void)disassociateNamedUserIfNil;


@end

NS_ASSUME_NONNULL_END
