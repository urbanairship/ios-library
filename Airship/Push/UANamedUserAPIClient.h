/*
 Copyright 2009-2015 Urban Airship Inc. All rights reserved.

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

@class UAHTTPRequestEngine;
@class UAHTTPRequest;
@class UAConfig;

/**
 * A block called when named user association or disassociation succeeded.
 */
typedef void (^UANamedUserAPIClientSuccessBlock)();

/**
 * A block called when named user association or disassociation failed.
 *
 * @param request The request that failed.
 */
typedef void (^UANamedUserAPIClientFailureBlock)(UAHTTPRequest *request);

/**
 * A high level abstraction for performing Named User API association and disassociation.
 */
@interface UANamedUserAPIClient : NSObject


/**
 * Factory method to create a UANamedUserAPIClient.
 * @param config the Urban Airship config.
 * @return UANamedUserAPIClient instance.
 */
+ (instancetype)clientWithConfig:(UAConfig *)config;

/**
 * Associates the channel to the named user ID.
 *
 * @param identifier The named user ID string.
 * @param channelID The channel ID string.
 * @param successBlock A UANamedUserAPIClientCreateSuccessBlock that will be
 *        called if the named user ID was associated successfully.
 * @param failureBlock A UANamedUserAPIClientFailureBlock that will be called
 *        if the named user ID association was unsuccessful.
 */
- (void)associate:(NSString *)identifier
        channelID:(NSString *)channelID
        onSuccess:(UANamedUserAPIClientSuccessBlock)successBlock
        onFailure:(UANamedUserAPIClientFailureBlock)failureBlock;

/**
 * Disassociate the channel from the named user ID.
 *
 * @param channelID The channel ID string.
 * @param successBlock A UANamedUserAPIClientCreateSuccessBlock that will be
 *        called if the named user ID was disassociated successfully.
 * @param failureBlock A UANamedUserAPIClientFailureBlock that will be called
 *        if the named user ID disassociation was unsuccessful.
 */
- (void)disassociate:(NSString *)channelID
           onSuccess:(UANamedUserAPIClientSuccessBlock)successBlock
           onFailure:(UANamedUserAPIClientFailureBlock)failureBlock;

/**
 * Indicates whether the client should attempt to automatically retry HTTP connections
 * under recoverable conditions (most 5xx status codes, reachability errors, etc).
 * In this case, the client will perform exponential backoff and schedule reconnections
 * accordingly before calling back with a success or failure.  Defaults to `YES`.
 */
@property (nonatomic, assign) BOOL shouldRetryOnConnectionError;

/**
 * The client's request engine.
 */
@property (nonatomic, strong) UAHTTPRequestEngine *requestEngine;

@end
