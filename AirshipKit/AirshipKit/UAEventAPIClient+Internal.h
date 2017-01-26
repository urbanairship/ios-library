/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

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
#import "UAAPIClient+Internal.h"

@class UAConfig;

NS_ASSUME_NONNULL_BEGIN

/**
 * API client to upload events to Urban Airship.
 */
@interface UAEventAPIClient : UAAPIClient

/**
 * Default factory method.
 *
 * @param config The Urban Airship config.
 * @return A UAEventAPIClient instance.
 */
+ (instancetype)clientWithConfig:(UAConfig *)config;

/**
 * Factory method to create a UAEventAPIClient.
 *
 * @param config The Urban Airship config.
 * @param session The UARequestSession instance.
 * @return UAEventAPIClient instance.
 */
+ (instancetype)clientWithConfig:(UAConfig *)config session:(UARequestSession *)session;

/**
 * Uploads analytic events.
 * @param events The events to upload.
 * @param completionHandler A completion handler.
 */
-(void)uploadEvents:(NSArray *)events completionHandler:(void (^)(NSHTTPURLResponse * nullable))completionHandler;

@end

NS_ASSUME_NONNULL_END
