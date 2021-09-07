/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAUserData.h"

#import "UAAirshipMessageCenterCoreImport.h"

@class UADispatcher;
@class UARuntimeConfig;

NS_ASSUME_NONNULL_BEGIN

/**
 * Data access object for user data.
 */
@interface UAUserDataDAO : NSObject

/**
 * User DAO factory method.
 * @param config The runtime config.
 * @return A user DAO object.
 */
+ (instancetype)userDataDAOWithConfig:(UARuntimeConfig *)config;

/**
 * Gets the data associated with the user.
 *
 * @param completionHandler A completion handler which will be called with the user data.
 * @param queue The queue on which to invoke the completion handler.
 */
- (void)getUserData:(void (^)(UAUserData *))completionHandler queue:(nullable dispatch_queue_t)queue;

/**
 * Gets the data associated with the user.
 *
 * @param completionHandler A completion handler which will be called with the user data.
 */
- (void)getUserData:(void (^)(UAUserData *))completionHandler;

/**
 * Gets the data associated with the user.
 *
 * @param completionHandler A completion handler which will be called with the user data.
 * @param dispatcher The dispatcher on which to invoked the completion handler.
 */
- (void)getUserData:(void (^)(UAUserData * _Nullable))completionHandler dispatcher:(nullable UADispatcher *)dispatcher;


/**
 * Gets the data associated with the user, synchronously.
 *
 * Note: This method may block the calling thread, and thus should be avoided while working on the main queue.
 *
 * @return The user data, or `nil` if no data is available.
 */
- (nullable UAUserData *)getUserDataSync;

/**
 * Save username and password data to disk.
 */
- (void)saveUserData:(UAUserData *)data completionHandler:(void (^)(BOOL))completionHandler;

/**
 * Removes the existing user from the keychain.
 */
- (void)clearUser;

@end

NS_ASSUME_NONNULL_END
