/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

#import "UAAirshipMessageCenterCoreImport.h"
#import "UAUserData.h"

@class UAHTTPResponse;
@class UARequestSession;
@class UADisposable;
@class UARuntimeConfig;

NS_ASSUME_NONNULL_BEGIN

/**
 * Create user response.
 */
@interface UAUserCreateResponse : NSObject

/**
 * The HTTP status.
 */
@property(nonatomic, assign, readonly) NSUInteger status;

/**
 * Created user data.
 */
@property(nonatomic, readonly, nullable) UAUserData *userData;

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

/**
 * Init method.
 * @param status The HTTP status.
 * @param userData The optional user data.
 */
- (instancetype)initWithStatus:(NSUInteger)status userData:(nullable UAUserData *)userData;

@end


/**
 * High level abstraction for the User API.
 */
@interface UAUserAPIClient : NSObject

///---------------------------------------------------------------------------------------
/// @name User API Client Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method to create a UAUserAPIClient.
 * @param config The Airship config.
 * @return UAUserAPIClient instance.
 */
+ (instancetype)clientWithConfig:(UARuntimeConfig *)config;

/**
 * Factory method to create a UAUserAPIClient.
 * @param config The Airship config.
 * @param session The request session.
 * @return UAUserAPIClient instance.
 */
+ (instancetype)clientWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session;

/**
 * Create a user.
 *
 * @param channelID The user's channel ID.
 * @param completionHandler The completion handler. If an error is present the the response will be nil.
 * @return A disposable to cancel the request. The completion handler will still be called with an error.
 */
- (UADisposable *)createUserWithChannelID:(NSString *)channelID
                        completionHandler:(void (^)(UAUserCreateResponse * _Nullable response, NSError * _Nullable error))completionHandler;

/**
 * Update a user.
 *
 * @param userData The user data to update.
 * @param channelID The user's channel ID.
 * @param completionHandler The completion handler. If an error is present the response wil be nil.
 * @return A disposable to cancel the request. The completion handler will  be called with an error.
 */
- (UADisposable *)updateUserWithData:(UAUserData *)userData
                           channelID:(NSString *)channelID
                   completionHandler:(void (^)(UAHTTPResponse * _Nullable response, NSError * _Nullable error))completionHandler;


@end

NS_ASSUME_NONNULL_END
