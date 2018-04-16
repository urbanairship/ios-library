/* Copyright 2018 Urban Airship and Contributors */


#import <Foundation/Foundation.h>
#import "UAAPIClient+Internal.h"

@class UAConfig;
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
 * Factory method to create a UATagGroupsAPIClient for channel tag groups.
 *
 * @param config The Urban Airship config.
 * @return UATagGroupsAPIClient instance.
 */
+ (instancetype)channelClientWithConfig:(UAConfig *)config;

/**
 * Factory method to create a UATagGroupsAPIClient.
 *
 * @param config The Urban Airship config.
 * @param session The request session.
 * @return UATagGroupsAPIClient instance.
 */
+ (instancetype)channelClientWithConfig:(UAConfig *)config session:(UARequestSession *)session;

/**
 * Factory method to create a UATagGroupsAPIClient for named user tag groups.
 *
 * @param config The Urban Airship config.
 * @return UATagGroupsAPIClient instance.
 */
+ (instancetype)namedUserClientWithConfig:(UAConfig *)config;

/**
 * Factory method to create a UATagGroupsAPIClient.
 *
 * @param config The Urban Airship config.
 * @param session The request session.
 * @return UATagGroupsAPIClient instance.
 */
+ (instancetype)namedUserClientWithConfig:(UAConfig *)config session:(UARequestSession *)session;

/**
 * Update the tag group for the identifier.
 *
 * @param identifier The ID string.
 * @param mutation The tag groups changes.
 * @param completionHandler The completion handler with the status code.
 */
- (void)updateTagGroupsForId:(NSString *)identifier
    tagGroupsMutation:(UATagGroupsMutation *)mutation
    completionHandler:(void (^)(NSUInteger status))completionHandler;

@end

NS_ASSUME_NONNULL_END
