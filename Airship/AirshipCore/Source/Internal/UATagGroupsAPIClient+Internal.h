/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UARequestSession.h"
#import "UARuntimeConfig.h"
#import "UATagGroupsMutation.h"
#import "UAHTTPResponse.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A high level abstraction for performing tag group operations.
 */
@interface UATagGroupsAPIClient : NSObject

///---------------------------------------------------------------------------------------
/// @name Tag Groups API Client Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method to create a UATagGroupsAPIClient with channel tag groups type.
 *
 * @param config The Airship config.
 * @return UATagGroupsAPIClient instance.
 */
+ (instancetype)channelClientWithConfig:(UARuntimeConfig *)config;

/**
 * Factory method to create a UATagGroupsAPIClient  with channel tag groups type.
 *
 * @param config The Airship config.
 * @param session The request session.
 * @return UATagGroupsAPIClient instance.
 */
+ (instancetype)channelClientWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session;

/**
 * Factory method to create a UATagGroupsAPIClient with named user tag groups type.
 *
 * @param config The Airship config.
 * @return UATagGroupsAPIClient instance.
 */
+ (instancetype)namedUserClientWithConfig:(UARuntimeConfig *)config;

/**
 * Factory method to create a UATagGroupsAPIClient with named user tag groups type.
 *
 * @param config The Airship config.
 * @param session The request session.
 * @return UATagGroupsAPIClient instance.
 */
+ (instancetype)namedUserClientWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session;

/**
 * Update the tag group for the identifier.
 *
 * @param identifier The ID string.
 * @param mutation The tag groups changes.
 * @param completionHandler The completion handler.
 */
- (UADisposable *)updateTagGroupsForId:(NSString *)identifier
                     tagGroupsMutation:(UATagGroupsMutation *)mutation
                     completionHandler:(void (^)(UAHTTPResponse *response, NSError * _Nullable))completionHandler;

@end

NS_ASSUME_NONNULL_END

