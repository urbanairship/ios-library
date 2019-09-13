/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAAPIClient+Internal.h"
#import "UAAnalytics+Internal.h"

@class UARuntimeConfig;

NS_ASSUME_NONNULL_BEGIN

/**
 * API client to upload events to Airship.
 */
@interface UAEventAPIClient : UAAPIClient

///---------------------------------------------------------------------------------------
/// @name Event API Client Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Default factory method.
 *
 * @param config The Airship config.
 * @return A UAEventAPIClient instance.
 */
+ (instancetype)clientWithConfig:(UARuntimeConfig *)config;

/**
 * Factory method to create a UAEventAPIClient.
 *
 * @param config The Airship config.
 * @param session The UARequestSession instance.
 * @return UAEventAPIClient instance.
 */
+ (instancetype)clientWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session;

/**
 * Uploads analytic events.
 * @param events The events to upload.
 * @param completionHandler A completion handler.
 */
-(void)uploadEvents:(NSArray *)events completionHandler:(void (^)(NSHTTPURLResponse * nullable))completionHandler;

@end

NS_ASSUME_NONNULL_END
