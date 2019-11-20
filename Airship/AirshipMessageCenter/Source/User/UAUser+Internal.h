/* Copyright Airship and Contributors */

#import "UAUser.h"
#import "UAUserDataDAO+Internal.h"
#import "UAUserAPIClient+Internal.h"

#import "UAAirshipMessageCenterCoreImport.h"

NS_ASSUME_NONNULL_BEGIN

/*
 * SDK-private extensions to UAUser
 */
@interface UAUser()

///---------------------------------------------------------------------------------------
/// @name User Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method to create a user instance.
 * @param channel The channel.
 * @param config The Airship config.
 * @param dataStore The preference data store.
 * @return User instance.
 */
+ (instancetype)userWithChannel:(UAChannel<UAExtendableChannelRegistration> *)channel
                         config:(UARuntimeConfig *)config
                      dataStore:(UAPreferenceDataStore *)dataStore;

/**
 * Factory method to create a user instance. Used for testing.
 * @param channel The channel.
 * @param dataStore The preference data store.
 * @param client The API client.
 * @param notificationCenter The notification center.
 * @param application The application.
 * @param backgroundDispatcher The dispatcher.
 * @param userDataDAO The user data DAO.
 * @return User instance.
 */
+ (instancetype)userWithChannel:(UAChannel<UAExtendableChannelRegistration> *)channel
                      dataStore:(UAPreferenceDataStore *)dataStore
                         client:(UAUserAPIClient *)client
             notificationCenter:(NSNotificationCenter *)notificationCenter
                    application:(UIApplication *)application
           backgroundDispatcher:(UADispatcher *)backgroundDispatcher
                    userDataDAO:(UAUserDataDAO *)userDataDAO;

/**
 * Gets the data associated with the user.
 *
 * @param completionHandler A completion handler which will be called with the user data.
 * @param dispatcher The dispatcher on which to invoked the completion handler.
 */
- (void)getUserData:(void (^)(UAUserData * _Nullable))completionHandler dispatcher:(nullable UADispatcher *)dispatcher;

/**
 * Removes the existing user from the keychain.
 */
- (void)resetUser;

/**
 * Flag indicating whether the user is enabled. Clear to disable. Set to enable.
 */
@property (nonatomic, assign) BOOL enabled;

@end

NS_ASSUME_NONNULL_END

