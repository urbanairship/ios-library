/* Copyright Airship and Contributors */

#import "UAMessageCenter.h"
#import "UAPushableComponent.h"

@class UAUser;
@class UARuntimeConfig;
@class UAPreferenceDataStore;

NS_ASSUME_NONNULL_BEGIN

/*
 * SDK-private extensions to UAMessageCenter
 */
@interface UAMessageCenter () <UAPushableComponent>


///---------------------------------------------------------------------------------------
/// @name Message Center Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method.
 * @param dataStore The data store.
 * @param config The config
 * @param channel The channel.
 * @return A message center instance.
 */
+ (instancetype)messageCenterWithDataStore:(UAPreferenceDataStore *)dataStore
                                    config:(UARuntimeConfig *)config
                                   channel:(UAChannel<UAExtendableChannelRegistration> *)channel;

/**
 * Factory method for testing.
 * @param dataStore The data store.
 * @param user The user.
 * @param messageList The message list.
 * @param defaultUI The default UI.
 * @param notificationCenter The notification center.
 * @return A message center instance.
*/
+ (instancetype)messageCenterWithDataStore:(UAPreferenceDataStore *)dataStore
                                      user:(UAUser *)user
                               messageList:(UAInboxMessageList *)messageList
                                 defaultUI:(UADefaultMessageCenterUI *)defaultUI
                        notificationCenter:(NSNotificationCenter *)notificationCenter;

@end

NS_ASSUME_NONNULL_END
