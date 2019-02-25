/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "UAComponent.h"
#import "UAUserData.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString * const UAUserCreatedNotification;

/**
 * Primary interface for working with the application's associated UA user.
 */
@interface UAUser : UAComponent

///---------------------------------------------------------------------------------------
/// @name User Properties
///---------------------------------------------------------------------------------------

/**
 * Indicates whether the default user has been created.
 *
 * @deprecated Deprecated - to be removed in SDK version 11.0. Please use `getUserData:`
 * @return `YES` if the user has been created, `NO` otherwise.
 */
@property (nonatomic, readonly, getter=isCreated) BOOL created DEPRECATED_MSG_ATTRIBUTE("Deprecated - to be removed in SDK version 11.0. Please use getUserData:");

/**
 * The user name.
 *
 * @deprecated Deprecated - to be removed in SDK version 11.0. Please use `getUserData:`
 */
@property (nonatomic, readonly, copy, nullable) NSString *username DEPRECATED_MSG_ATTRIBUTE("Deprecated - to be removed in SDK version 11.0. Please use getUserData:");;

/**
 * The user password.
 *
 * @deprecated Deprecated - to be removed in SDK version 11.0. Please use `getUserData:`
 */
@property (nonatomic, readonly, copy, nullable) NSString *password DEPRECATED_MSG_ATTRIBUTE("Deprecated - to be removed in SDK version 11.0. Please use getUserData:");

/**
 * The user url.
 *
 * @deprecated Deprecated - to be removed in SDK version 11.0. Please use `getUserData:`
 */
@property (nonatomic, readonly, nullable) NSString *url DEPRECATED_MSG_ATTRIBUTE("Deprecated - to be removed in SDK version 11.0. Please use getUserData:");

/**
 * Gets the data associated with the user.
 *
 * @param completionHandler A completion handler which will be called with the user data.
 * @param queue The queue on which to invoke the completion handler.
 */
- (void)getUserData:(void (^)(UAUserData * _Nullable))completionHandler queue:(nullable dispatch_queue_t)queue;

/**
 * Gets the data associated with the user.
 *
 * @param completionHandler A completion handler which will be called with the user data.
 */
- (void)getUserData:(void (^)(UAUserData *))completionHandler;

/**
 * Gets the data associated with the user, synchronously.
 *
 * Note: This method may block the calling thread, and thus should be avoided while working on the main queue.
 *
 * @return The user data, or `nil` if no data is available.
 */
- (nullable UAUserData *)getUserDataSync;

@end

NS_ASSUME_NONNULL_END

