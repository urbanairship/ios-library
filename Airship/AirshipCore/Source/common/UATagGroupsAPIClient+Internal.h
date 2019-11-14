/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAAPIClient+Internal.h"
#import "UATagGroupsType+Internal.h"

@class UARuntimeConfig;
@class UATagGroupsMutation;

NS_ASSUME_NONNULL_BEGIN

/**
 * A high level abstraction for performing tag group operations.
 */
@interface UATagGroupsAPIClient : UAAPIClient

///---------------------------------------------------------------------------------------
/// @name Tag Groups API Client Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method to create a UATagGroupsAPIClient.
 *
 * @param config The Airship config.
 * @return UATagGroupsAPIClient instance.
 */
+ (instancetype)clientWithConfig:(UARuntimeConfig *)config;

/**
 * Factory method to create a UATagGroupsAPIClient.
 *
 * @param config The Airship config.
 * @param session The request session.
 * @return UATagGroupsAPIClient instance.
 */
+ (instancetype)clientWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session;

/**
 * Update the tag group for the identifier.
 *
 * @param identifier The ID string.
 * @param mutation The tag groups changes.
 * @param type The tag groups type.
 * @param completionHandler The completion handler with the status code.
 */
- (void)updateTagGroupsForId:(NSString *)identifier
           tagGroupsMutation:(UATagGroupsMutation *)mutation
                        type:(UATagGroupsType)type
           completionHandler:(void (^)(NSUInteger status))completionHandler;

@end

NS_ASSUME_NONNULL_END
