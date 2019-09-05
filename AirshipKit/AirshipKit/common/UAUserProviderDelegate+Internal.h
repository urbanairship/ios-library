/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAUserData.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Protocol for bridging inbox user functionality with the SDK.
 */
@protocol UAUserProviderDelegate <NSObject>

/**
 * Gets the data associated with the user.
 *
 * @param completionHandler A completion handler which will be called with the user data.
 * @param dispatcher The dispatcher on which to invoked the completion handler.
 */
- (void)getUserData:(void (^)(UAUserData *))completionHandler dispatcher:(nullable UADispatcher *)dispatcher;

@end

NS_ASSUME_NONNULL_END
