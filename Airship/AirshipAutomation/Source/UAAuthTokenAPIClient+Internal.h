/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAAuthToken+Internal.h"
#import "UAAirshipAutomationCoreImport.h"
#import "UAHTTPResponse.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents possible auth token API client errors.
 */
typedef NS_ENUM(NSInteger, UAAuthTokenAPIClientError) {
    /**
     * Indicates an unsuccessful status error.
     */
    UAAuthTokenAPIClientErrorUnsuccessfulStatus,

    /**
     * Indicates an invalid server response.
     */
    UAAuthTokenAPIClientErrorInvalidResponse
};

/**
 * The domain for NSErrors generated by `tokenWithCompletionHandler:`.
 */
extern NSString * const UAAuthTokenAPIClientErrorDomain;

/**
 * Auth token response.
 */
@interface UAAuthTokenResponse : UAHTTPResponse

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
