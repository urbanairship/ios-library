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
#import "UAAPIClient+Internal.h"

@class UAUser;
@class UAConfig;
@class UAUserData;

NS_ASSUME_NONNULL_BEGIN

/**
 * A block called when user creation succeeded.
 *
 * @param data The user data.
 * @param payload The request payload.
 */
typedef void (^UAUserAPIClientCreateSuccessBlock)(UAUserData *data, NSDictionary *payload);

/**
 * A block called when the user update succeeded.
 */
typedef void (^UAUserAPIClientUpdateSuccessBlock)();

/**
 * A block called when the user update failed.
 *
 * @param statusCode The request status code.
 */
typedef void (^UAUserAPIClientFailureBlock)(NSUInteger statusCode);

/**
 * High level abstraction for the User API.
 */
@interface UAUserAPIClient : UAAPIClient

/**
 * Factory method to create a UAUserAPIClient.
 * @param config The Urban Airship config.
 * @return UAUserAPIClient instance.
 */
+ (instancetype)clientWithConfig:(UAConfig *)config;

/**
 * Factory method to create a UAUserAPIClient.
 * @param config The Urban Airship config.
 * @param session The request session.
 * @return UAUserAPIClient instance.
 */
+ (instancetype)clientWithConfig:(UAConfig *)config session:(UARequestSession *)session;

/**
 * Create a user.
 * 
 * @param channelID The user's channel ID.
 * @param successBlock A UAUserAPIClientCreateSuccessBlock that will be called if user creation was successful.
 * @param failureBlock A UAUserAPIClientFailureBlock that will be called if user creation was unsuccessful.
 */
- (void)createUserWithChannelID:(NSString *)channelID
                      onSuccess:(UAUserAPIClientCreateSuccessBlock)successBlock
                      onFailure:(UAUserAPIClientFailureBlock)failureBlock;

/**
 * Update a user.
 *
 * @param user The specified user to update.
 * @param channelID The user's channel ID.
 * @param successBlock A UAUserAPIClientUpdateSuccessBlock that will be called if the update was successful.
 * @param failureBlock A UAUserAPIClientFailureBlock that will be called if the update was unsuccessful.
 */
- (void)updateUser:(UAUser *)user
         channelID:(NSString *)channelID
         onSuccess:(UAUserAPIClientUpdateSuccessBlock)successBlock
         onFailure:(UAUserAPIClientFailureBlock)failureBlock;

@end

NS_ASSUME_NONNULL_END
