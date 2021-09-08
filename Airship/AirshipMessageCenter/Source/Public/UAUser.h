/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "UAUserData.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString * const UAUserCreatedNotification;

/**
 * Primary interface for working with the application's associated Airship user.
 */
NS_SWIFT_NAME(User)
@interface UAUser : NSObject

///---------------------------------------------------------------------------------------
/// @name User Properties
///---------------------------------------------------------------------------------------

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
 * Gets the data associated with the user, synchronously.
 *
 * Note: This method may block the calling thread, and thus should be avoided while working on the main queue.
 *
 * @return The user data, or `nil` if no data is available.
 */
- (nullable UAUserData *)getUserDataSync;

@end

NS_ASSUME_NONNULL_END

