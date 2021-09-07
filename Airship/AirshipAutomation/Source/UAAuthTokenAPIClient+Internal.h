/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAAuthToken+Internal.h"
#import "UAAirshipAutomationCoreImport.h"

@class UARequestSession;
@class UARuntimeConfig;

NS_ASSUME_NONNULL_BEGIN


/**
 * Auth token response.
 */
@interface UAAuthTokenResponse : NSObject

/**
 * The HTTP status.
 */
@property(nonatomic, assign, readonly) NSUInteger status;



/**
 * The auth token.
 */
@property(nonatomic, readonly, nullable) UAAuthToken *token;

/**
 * Init method.
 * @param status The HTTP status.
 * @param token  The auth token.
 */
- (instancetype)initWithStatus:(NSUInteger)status authToken:(nullable UAAuthToken *)token;


/**
 * Checks if the status is success (2xx).
 * @return `YES` if success, otherwise `NO`.
 */
- (bool)isSuccess;

/**
 * Checks if the status is client error (4xx).
 * @return `YES` if client error, otherwise `NO`.
 */
- (bool)isClientError;

/**
 * Checks if the status is server error (5xx).
 * @return `YES` if server error, otherwise `NO`.
 */
- (bool)isServerError;

@end

/**
 * API client for retrieving auth tokens from the server.
 */
@interface UAAuthTokenAPIClient : NSObject

/**
 * UAAuthTokenAPIClient class factory method. Used for testing.
 *
 * @param config The runtime config.
 * @param session The request session.
 */
+ (instancetype)clientWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session;

/**
 * UAAuthTokenAPIClient class factory method.
 *
 * @param config The runtime config.
 */
+ (instancetype)clientWithConfig:(UARuntimeConfig *)config;

/**
 * Retrieves the token associated with the provided channel ID.
 *
 * @param channelID The channel ID.
 * @param completionHandler The completion handler invoked with the auth response and an NSError if the request fails.
 */
- (void)tokenWithChannelID:(NSString *)channelID completionHandler:(void (^)(UAAuthTokenResponse * _Nullable, NSError * _Nullable))completionHandler;

@end

NS_ASSUME_NONNULL_END
