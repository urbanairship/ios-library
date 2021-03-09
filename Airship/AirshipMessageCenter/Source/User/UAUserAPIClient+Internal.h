/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

#import "UAAirshipMessageCenterCoreImport.h"
#import "UAUserData.h"
#import "UAHTTPResponse.h"


NS_ASSUME_NONNULL_BEGIN

/**
 * Create user response.
 */
@interface UAUserCreateResponse : UAHTTPResponse

/**
 * Created user data.
 */
@property(nonatomic, readonly, nullable) UAUserData *userData;

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
