/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UARequestSession.h"
#import "UAChannelRegistrationPayload+Internal.h"
#import "UARuntimeConfig.h"
#import "UAHTTPResponse.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Channel create response.
 */
@interface UAChannelCreateResponse : UAHTTPResponse

/**
 * Created channel ID.
 */
@property(nonatomic, copy, readonly, nullable) NSString *channelID;

/**
 * Init method.
 * @param status The HTTP status.
 * @param channelID The optional channel ID.
 */
- (instancetype)initWithStatus:(NSUInteger)status channelID:(nullable NSString *)channelID;

@end

/**
 * A block called when the channel ID creation request completes.
 *
 * @param response The channel create response.
 * @param error The error.
 */
typedef void (^UAChannelAPIClientCreateCompletionHandler)(UAChannelCreateResponse * _Nullable response, NSError * _Nullable error);

/**
 * A block called when the channel update request completes.
 *
 * @param response The update response.
 * @param error The error.
 */
typedef void (^UAChannelAPIClientUpdateCompletionHandler)(UAHTTPResponse * _Nullable response, NSError * _Nullable error);

/**
 * A high level abstraction for performing Channel API creation and updates.
 */
@interface UAChannelAPIClient : NSObject

///---------------------------------------------------------------------------------------
/// @name Channel API Client Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method to create a UAChannelAPIClient.
 * @param config The Airship config.
 * @return UAChannelAPIClient instance.
 */
+ (instancetype)clientWithConfig:(UARuntimeConfig *)config;

/**
 * Factory method to create a UAChannelAPIClient.
 * @param config The Airship config.
 * @param session The UARequestSession instance.
 * @return UAChannelAPIClient instance.
 */
+ (instancetype)clientWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session;

/**
 * Create the channel ID.
 *
 * @param payload An instance of UAChannelRegistrationPayload.
 * @param completionHandler A UAChannelAPIClientCreateCompletionHandler.
 * @return A disposable.
 *
 */
- (UADisposable *)createChannelWithPayload:(UAChannelRegistrationPayload *)payload
                         completionHandler:(UAChannelAPIClientCreateCompletionHandler)completionHandler;

/**
 * Update the channel.
 *
 * @param channelID The channel identifier.
 * @param payload An instance of UAChannelRegistrationPayload.
 * @param completionHandler A UAChannelAPIClientUpdateCompletionHandler.
 * @return A disposable.
 *
 */
- (UADisposable *)updateChannelWithID:(NSString *)channelID
                          withPayload:(UAChannelRegistrationPayload *)payload
                    completionHandler:(UAChannelAPIClientUpdateCompletionHandler)completionHandler;

@end

NS_ASSUME_NONNULL_END
