/* Copyright Airship and Contributors */

#import "UAMessageCenter.h"

#import "UAAirshipMessageCenterCoreImport.h"

@class UAUser;
@class UARuntimeConfig;
@class UAPreferenceDataStore;
@class UAPrivacyManager;
@class UAChannel;

NS_ASSUME_NONNULL_BEGIN

/*
 * SDK-private extensions to UAMessageCenter
 */
@interface UAMessageCenter ()


///---------------------------------------------------------------------------------------
/// @name Message Center Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method.
 * @param dataStore The data store.
 * @param config The config
 * @param channel The channel.
 * @param privacyManager The privacy manager.
 * @return A message center instance.
 */
+ (instancetype)messageCenterWithDataStore:(UAPreferenceDataStore *)dataStore
                                    config:(UARuntimeConfig *)config
                                   channel:(UAChannel *)channel
                            privacyManager:(UAPrivacyManager *)privacyManager;

/**
 * Factory method for testing.
 * @param dataStore The data store.
 * @param user The user.
 * @param messageList The message list.
 * @param defaultUI The default UI.
 * @param notificationCenter The notification center.
 * @param privacyManager The privacy manager.
 * @return A message center instance.
*/
+ (instancetype)messageCenterWithDataStore:(UAPreferenceDataStore *)dataStore
                                      user:(UAUser *)user
                               messageList:(UAInboxMessageList *)messageList
                                 defaultUI:(UADefaultMessageCenterUI *)defaultUI
                        notificationCenter:(NSNotificationCenter *)notificationCenter
                            privacyManager:(UAPrivacyManager *)privacyManager;

@end

NS_ASSUME_NONNULL_END
