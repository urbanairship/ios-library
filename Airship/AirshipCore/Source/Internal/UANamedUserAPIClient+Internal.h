/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UARequestSession.h"
#import "UARuntimeConfig.h"
#import "UAHTTPResponse.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A high level abstraction for performing Named User API association and disassociation.
 */
@interface UANamedUserAPIClient : NSObject

///---------------------------------------------------------------------------------------
/// @name Named User Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method to create a UANamedUserAPIClient.
 * @param config The Airship config.
 * @return UANamedUserAPIClient instance.
 */
+ (instancetype)clientWithConfig:(UARuntimeConfig *)config;

/**
 * Factory method to create a UANamedUserAPIClient.
 * @param config The Airship config.
 * @param session the request session.
 * @return UANamedUserAPIClient instance.
 */
+ (instancetype)clientWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session;

/**
 * Associates the channel to the named user ID.
 *
 * @param identifier The named user ID string.
 * @param channelID The channel ID string.
 * @param completionHandler The completion handler.
 */
- (UADisposable *)associate:(NSString *)identifier
                  channelID:(NSString *)channelID
          completionHandler:(void (^)(UAHTTPResponse * _Nullable, NSError * _Nullable))completionHandler;

/**
 * Disassociate the channel from the named user ID.
 *
 * @param channelID The channel ID string.
 * @param completionHandler The completion handler.
 */
- (UADisposable *)disassociate:(NSString *)channelID
             completionHandler:(void (^)(UAHTTPResponse * _Nullable, NSError * _Nullable))completionHandler;

@end

NS_ASSUME_NONNULL_END

