/* Copyright Airship and Contributors */
#import <Foundation/Foundation.h>
#import "UAAsyncOperation.h"
#import "UARequest.h"
#import "UARequestSession.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Performs an HTTP request in an NSOperation.
 */
@interface UAHTTPRequestOperation : UAAsyncOperation

/**
 * UAHTTPRequestOperation factory method.
 * @param request The request to perform.
 * @param session The url session to peform the request in.
 * @param completionHandler A completion handler to call once the request is finished.
 */
+ (instancetype)operationWithRequest:(UARequest *)request
                             session:(UARequestSession *)session
                   completionHandler:(UAHTTPRequestCompletionHandler)completionHandler;
@end

NS_ASSUME_NONNULL_END

