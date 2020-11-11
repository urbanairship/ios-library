/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UARuntimeConfig.h"
#import "UARequest.h"
#import "UARequestSession.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @note For internal use only. :nodoc:
 */
typedef BOOL (^UAHTTPRequestRetryBlock)(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response);

/**
 * @note For internal use only. :nodoc:
 */
@interface UAAPIClient : NSObject

/**
 * Status code to indicate the API client is disabled or otherwise unavailable
 * @note For internal use only. :nodoc:
 */
extern NSUInteger const UAAPIClientStatusUnavailable;

/**
 * The UARuntimeConfig instance.
 */
@property (nonatomic, readonly) UARuntimeConfig *config;

/**
 * The UARequestSession instance. Should be used to perform requests.
 */
@property (nonatomic, readonly) UARequestSession *session;

/**
 * Flag indicating whether the client is enabled. Clear to disable. Set to enable.
 */
@property (nonatomic, assign) BOOL enabled;

/**
 * Init method.
 * @param config The UARuntimeConfig instance.
 * @param session The UARequestSession instance.
 */
- (instancetype)initWithConfig:(UARuntimeConfig *)config
                       session:(UARequestSession *)session
                         queue:(nullable NSOperationQueue *)queue;

/**
 * Init method.
 * @param config The UARuntimeConfig instance.
 * @param session The UARequestSession instance.
 */
- (instancetype)initWithConfig:(UARuntimeConfig *)config
                       session:(UARequestSession *)session;

/**
 * Cancels all in-flight API requests.
 */
- (void)cancelAllRequests;

/**
 * Performs a request on the queue.
 * @param request The request.
 * @param completionHandler The completion handler.
 */
- (void)performRequest:(UARequest *)request
     completionHandler:(UAHTTPRequestCompletionHandler)completionHandler;

/**
 * Performs a request on the queue.
 * @param request The request.
 * @param retryBlock The retry block.
 * @param completionHandler The completion handler.
 */
- (void)performRequest:(UARequest *)request
            retryWhere:(nullable UAHTTPRequestRetryBlock)retryBlock
     completionHandler:(UAHTTPRequestCompletionHandler)completionHandler;

@end

NS_ASSUME_NONNULL_END
