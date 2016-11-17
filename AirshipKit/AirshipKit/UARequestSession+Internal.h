/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/Foundation.h>
#import "UARequest+Internal.h"
#import "UAConfig.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^UARequestCompletionHandler)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);
typedef BOOL (^UARequestRetryBlock)(NSData * _Nullable data, NSURLResponse * _Nullable response);

/**
 * Request session used for running UARequests.
 */
@interface UARequestSession : NSObject

/**
 * UARequestSession factory method.
 * @param config The UAConfig instance.
 * @return A UARequestSession instance.
 */
+ (instancetype)sessionWithConfig:(UAConfig *)config;

/**
 * UARequestSession factory method.
 * @param config The UAConfig instance.
 * @param session A NSURLSession instance.
 * @return A UARequestSession instance.
 */
+ (instancetype)sessionWithConfig:(UAConfig *)config NSURLSession:(NSURLSession *)session;

/**
 * UARequestSession factory method.
 * @param config The UAConfig instance.
 * @param session A NSURLSession instance.
 * @param queue A NSOperation to perform retries on.
 * @return A UARequestSession instance.
 */
+ (instancetype)sessionWithConfig:(UAConfig *)config NSURLSession:(NSURLSession *)session queue:(NSOperationQueue *)queue;

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
