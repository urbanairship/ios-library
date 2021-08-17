/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAAuthToken+Internal.h"
#import "UAAuthTokenAPIClient+Internal.h"

@class UADate;
@class UADispatcher;
@class UAChannel;

NS_ASSUME_NONNULL_BEGIN

/**
 * High level interface for retrieving and caching auth tokens.
 */
@interface UAAuthTokenManager : NSObject

/**
 * UAAuthTokenManager class factory method. Used for testing.
 *
 * @param client The API client.
 * @param channel The channel.
 * @param date The UADate.
 * @param dispatcher The serial dispatcher.
 */
+ (instancetype)authTokenManagerWithAPIClient:(UAAuthTokenAPIClient *)client
                                      channel:(UAChannel *)channel
                                         date:(UADate *)date
                                   dispatcher:(UADispatcher *)dispatcher;
/**
 * UAAuthTokenManager class factory method.
 *
 * @param config The runtime config.
 * @param channel The channel.
 */
+ (instancetype)authTokenManagerWithRuntimeConfig:(UARuntimeConfig *)config channel:(UAChannel *)channel;

/**
 * Retrieves the current auth token with the provided completion handler, or nil if one could not be retrieved.
 *
 * @param completionHandler The completion handler invoked with the retrieved auth token, or nil if one
 * could not be retrieved. The completion handler is called on an internal serial queue.
 */
- (void)tokenWithCompletionHandler:(void (^)(NSString * _Nullable))completionHandler;

/**
 * Manually expires the provided token.
 */
- (void)expireToken:(NSString *)token;

@end

NS_ASSUME_NONNULL_END
