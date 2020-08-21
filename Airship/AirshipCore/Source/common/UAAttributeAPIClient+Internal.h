/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAAPIClient.h"
#import "UAAttributePendingMutations+Internal.h"

@class UARuntimeConfig;

NS_ASSUME_NONNULL_BEGIN

extern NSString *const UAAttributePlatform;

/**
 A high level abstraction for performing mutations on the attribute API.
*/
@interface UAAttributeAPIClient : UAAPIClient


///---------------------------------------------------------------------------------------
/// @name Attribute API Client Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method to create a channel UAAttributeAPIClient.
 * @param config The Airship config.
 * @return UAAttributeAPIClient instance.
 */
+ (instancetype)channelClientWithConfig:(UARuntimeConfig *)config;

/**
 * Factory method to create a named user UAAttributeAPIClient.
 * @param config The Airship config.
 * @return UAAttributeAPIClient instance.
 */
+ (instancetype)namedUserClientWithConfig:(UARuntimeConfig *)config;

/**
 * Factory method to create a UAAttributeAPIClient. Used for testing.
 * @param config The Airship config.
 * @param session The UARequestSession instance.
 * @param URLFactoryBlock The URL factory block.
 * @return UAAttributeAPIClient instance.
 */
+ (instancetype)clientWithConfig:(UARuntimeConfig *)config
                         session:(UARequestSession *)session
                 URLFactoryBlock:(NSURL *(^)(UARuntimeConfig *, NSString *))URLFactoryBlock;

/**
 * Update the specified identifier with the provided attribute payload.
 * @param identifier The identifier.
 * @param mutations The mutations.
 * @param completionHandler A block that will be called with the result.
 */
- (void)updateWithIdentifier:(NSString *)identifier
          attributeMutations:(UAAttributePendingMutations *)mutations
           completionHandler:(void (^)(NSUInteger status, NSError * _Nullable error))completionHandler;

@end

NS_ASSUME_NONNULL_END
