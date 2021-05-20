/* Copyright Airship and Contributors */

#import "UANamedUser.h"
#import "UAExtendableChannelRegistration.h"
#import "UATagGroupsMutation+Internal.h"
#import "UATagGroupsRegistrar+Internal.h"
#import "UAAttributeRegistrar+Internal.h"

@class UANamedUserAPIClient;
@class UARuntimeConfig;
@class UAChannel;
@class UADate;
@class UATaskManager;

NS_ASSUME_NONNULL_BEGIN

/*
 * SDK-private extensions to UANamedUser
 */
@interface UANamedUser () <UATagGroupsRegistrarDelegate, UAAttributeRegistrarDelegate>


///---------------------------------------------------------------------------------------
/// @name Named User Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method to create a named user. For testing.
 * @param channel The UAChannel instance.
 * @param config The Airship config.
 * @param dataStore The shared preference data store.
 * @param privacyManager A UAPrivacyManager instance.
 * @return A named user instance.
 */
+ (instancetype)namedUserWithChannel:(UAChannel *)channel
                              config:(UARuntimeConfig *)config
                           dataStore:(UAPreferenceDataStore *)dataStore
                      privacyManager:(UAPrivacyManager *)privacyManager;

/**
 * Factory method to create a named user. For testing.
 * @param channel The UAChannel instance.
 * @param config The Airship config.
 * @param notificationCenter The notification center.
 * @param dataStore The shared preference data store.
 * @param tagGroupsRegistrar The tag groups registrar.
 * @param attributeRegistrar The attribute registrar
 * @param date The date for setting the timestamp.
 * @param taskManager The task manager.
 * @param namedUserClient The API client.
 * @param privacyManager A UAPrivacyManager instance.
 * @return A named user instance.
 */
+ (instancetype)namedUserWithChannel:(UAChannel *)channel
                              config:(UARuntimeConfig *)config
                  notificationCenter:(NSNotificationCenter *)notificationCenter
                           dataStore:(UAPreferenceDataStore *)dataStore
                  tagGroupsRegistrar:(UATagGroupsRegistrar *)tagGroupsRegistrar
                  attributeRegistrar:(UAAttributeRegistrar *)attributeRegistrar
                                date:(UADate *)date
                         taskManager:(UATaskManager *)taskManager
                     namedUserClient:(UANamedUserAPIClient *)namedUserClient
                      privacyManager:(UAPrivacyManager *)privacyManager;

@end

NS_ASSUME_NONNULL_END
