/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UARequest.h"
#import "UARuntimeConfig.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^UARequestCompletionHandler)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);
typedef BOOL (^UARequestRetryBlock)(NSData * _Nullable data, NSURLResponse * _Nullable response);

/**
 * Request session used for running UARequests.
 * @note For internal use only. :nodoc:
 */
@interface UARequestSession : NSObject

/**
 * UARequestSession factory method.
 * @param config The UARuntimeConfig instance.
 * @return A UARequestSession instance.
 */
+ (instancetype)sessionWithConfig:(UARuntimeConfig *)config;

/**
 * UARequestSession factory method.
 * @param config The UARuntimeConfig instance.
 * @param session A NSURLSession instance.
 * @return A UARequestSession instance.
 */
+ (instancetype)sessionWithConfig:(UARuntimeConfig *)config NSURLSession:(NSURLSession *)session;

/**
 * UARequestSession factory method.
 * @param config The UARuntimeConfig instance.
 * @param session A NSURLSession instance.
 * @param queue A NSOperation to perform retries on.
 * @return A UARequestSession instance.
 */
+ (instancetype)sessionWithConfig:(UARuntimeConfig *)config NSURLSession:(NSURLSession *)session queue:(NSOperationQueue *)queue;

/**
 * Sets a http request header for all requests.
 *
 * @param value The header value.
 * @param header The header name.
 */
- (void)setValue:(id)value forHeader:(NSString *)header;

/**
 * Starts a request task.
 *
 * @param request The UARequest to perform.
 * @param completionHandler A callback to be invoked once the request is completed.
 */
- (void)dataTaskWithRequest:(UARequest *)request
          completionHandler:(UARequestCompletionHandler)completionHandler;

/**
 * Starts a request task.
 *
 * @param request The UARequest to perform.
 * @param retryBlock An optional block that will be called before the completion handler to decide if the
 * request should be retried or not.
 * @param completionHandler A callback to be invoked once the request is completed.
 */
- (void)dataTaskWithRequest:(UARequest *)request
                 retryWhere:(nullable UARequestRetryBlock)retryBlock
          completionHandler:(UARequestCompletionHandler)completionHandler;

/**
 * Cancels all in-flight requests.
 */
- (void)cancelAllRequests;

@end

NS_ASSUME_NONNULL_END
