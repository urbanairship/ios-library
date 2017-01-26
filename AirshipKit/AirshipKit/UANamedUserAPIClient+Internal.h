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
 * A block called when named user association or disassociation succeeded.
 */
typedef void (^UANamedUserAPIClientSuccessBlock)();

/**
 * A block called when named user association or disassociation failed.
 *
 * @param status The failed request status.
 */
typedef void (^UANamedUserAPIClientFailureBlock)(NSUInteger status);

/**
 * A high level abstraction for performing Named User API association and disassociation.
 */
@interface UANamedUserAPIClient : UAAPIClient

/**
 * Factory method to create a UANamedUserAPIClient.
 * @param config the Urban Airship config.
 * @return UANamedUserAPIClient instance.
 */
+ (instancetype)clientWithConfig:(UAConfig *)config;

/**
 * Factory method to create a UANamedUserAPIClient.
 * @param config the Urban Airship config.
 * @param session the request session.
 * @return UANamedUserAPIClient instance.
 */
+ (instancetype)clientWithConfig:(UAConfig *)config session:(UARequestSession *)session;

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

@end

NS_ASSUME_NONNULL_END
