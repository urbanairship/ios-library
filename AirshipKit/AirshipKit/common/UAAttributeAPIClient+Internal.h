/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAAPIClient+Internal.h"

@class UARuntimeConfig;

NS_ASSUME_NONNULL_BEGIN

extern NSString *const UAAttributePlatform;

/**
 * A block called when the attribute mutation succeeded.
 */
typedef void (^UAAttributeAPIClientSuccessBlock)(void);

/**
 A block called when the attribute mutation failed.
 @param statusCode The request status code.
 */
typedef void (^UAAttributeAPIClientFailureBlock)(NSUInteger statusCode);

/**
 A high level abstraction for performing mutations on the attribute API.
*/
@interface UAAttributeAPIClient : UAAPIClient


///---------------------------------------------------------------------------------------
/// @name Attribute API Client Internal Methods
///---------------------------------------------------------------------------------------

/**
 Factory method to create a UAAttributeAPIClient.
 @param config The Airship config.
 @return UAAttributeAPIClient instance.
 */
+ (instancetype)clientWithConfig:(UARuntimeConfig *)config;

/**
 Factory method to create a UAAttributeAPIClient.
 @param config The Airship config.
 @param session The UARequestSession instance.
 @return UAAttributeAPIClient instance.
 */
+ (instancetype)clientWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session;

/**
 Update the specified channel attributes with the provided attribute payload.
 @param identifier The channel to update.
 @param payload An dictionary representing an attribute payload.
 @param successBlock A UAAttributeAPIClientSuccessBlock that will be called
         if the attribute was updated successfully.
 @param failureBlock A UAAttributeAPIClientFailureBlock that will be called if
         the attribute update was unsuccessful.
 */
- (void)updateChannel:(NSString *)identifier withAttributePayload:(NSDictionary *)payload
                                                        onSuccess:(UAAttributeAPIClientSuccessBlock)successBlock
                                                        onFailure:(UAAttributeAPIClientFailureBlock)failureBlock;

@end

NS_ASSUME_NONNULL_END
