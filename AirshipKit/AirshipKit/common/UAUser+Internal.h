/* Copyright Urban Airship and Contributors */

#import "UAUser.h"
#import "UADispatcher+Internal.h"

// Current dictionary keys
#define kUserUrlKey @"UAUserUrlKey"

@class UAUserAPIClient;
@class UAConfig;
@class UAPreferenceDataStore;
@class UAPush;

NS_ASSUME_NONNULL_BEGIN

/*
 * SDK-private extensions to UAUser
 */
@interface UAUser()

///---------------------------------------------------------------------------------------
/// @name User Internal Properties
///---------------------------------------------------------------------------------------

/**
 * The user api client
 */
@property (nonatomic, strong) UAUserAPIClient *apiClient;

/**
 * The user name.
 */
@property (nonatomic, copy, nullable) NSString *username;

/**
 * The user's password.
 */
@property (nonatomic, copy, nullable) NSString *password;

/**
 * The user data.
 */
@property (nonatomic, strong, nullable) UAUserData *userData;

/**
 * The preference data store
 */
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;

/**
 * The Urban Airship config
 */
@property (nonatomic, strong) UAConfig *config;

///---------------------------------------------------------------------------------------
/// @name User Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method to create a user instance.
 * @param push The push manager.
 * @param config The Urban Airship config.
 * @param dataStore The preference data store.
 * @return User instance.
 */
+ (instancetype)userWithPush:(UAPush *)push config:(UAConfig *)config dataStore:(UAPreferenceDataStore *)dataStore;

/**
 * Factory method to create a user instance. Used for testing.
 * @param push The push manager.
 * @param config The Urban Airship config.
 * @param dataStore The preference data store.
 * @param client The API client.
 * @param notificationCenter The notification center.
 * @param application The application.
 * @param dispatcher The dispatcher.
 * @return User instance.
 */
+ (instancetype)userWithPush:(UAPush *)push
                      config:(UAConfig *)config
                   dataStore:(UAPreferenceDataStore *)dataStore
                      client:(UAUserAPIClient *)client
          notificationCenter:(NSNotificationCenter *)notificationCenter
                 application:(UIApplication *)application
                  dispatcher:(UADispatcher *)dispatcher;

/**
 * Updates the user's device token and or channel ID
 */
- (void)updateUser:(void (^_Nullable)(void))completionHandler;

/**
 * Creates a user, passing the user data to the completion handler if successful.
 */
- (void)createUser:(void (^_Nullable)(UAUserData *))completionHandler;

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

@end

NS_ASSUME_NONNULL_END

