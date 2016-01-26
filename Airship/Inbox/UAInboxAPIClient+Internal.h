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
#import "UAHTTPConnection+Internal.h"

@class UAUser;
@class UAConfig;
@class UAPreferenceDataStore;

NS_ASSUME_NONNULL_BEGIN

#define kUAChannelIDHeader @"X-UA-Channel-ID"

typedef void (^UAInboxClientFailureBlock)(UAHTTPRequest *request);
typedef void (^UAInboxClientSuccessBlock)(void);
typedef void (^UAInboxClientMessageRetrievalSuccessBlock)(NSInteger status,  NSArray * __nullable messages, NSInteger unread);

/**
 * A high level abstraction for performing Rich Push API requests.
 */
@interface UAInboxAPIClient : NSObject

/**
 * Factory method for client.
 * @param user The inbox user.
 * @param dataStore The preference data store.
 * @param config The Urban Airship config.
 * @return UAInboxAPIClient instance.
 */
+ (instancetype)clientWithUser:(UAUser *)user
                        config:(UAConfig *)config
                     dataStore:(UAPreferenceDataStore *)dataStore;

/**
 * Retrieves the full message list from the server.
 *
 * @param successBlock A block to be executed when the call completes successfully.
 * @param failureBlock A block to be executed if the call fails.
 */
- (void)retrieveMessageListOnSuccess:(UAInboxClientMessageRetrievalSuccessBlock)successBlock
                           onFailure:(UAInboxClientFailureBlock)failureBlock;

/**
 * Performs a batch delete request on the server.
 *
 * @param messages An NSArray of messages to be deleted.
 * @param successBlock A block to be executed when the call completes successfully.
 * @param failureBlock A block to be executed if the call fails.
 */

- (void)performBatchDeleteForMessages:(NSArray *)messages
                            onSuccess:(UAInboxClientSuccessBlock)successBlock
                            onFailure:(UAInboxClientFailureBlock)failureBlock;

/**
 * Performs a batch mark-as-read request on the server.
 *
 * @param messages An NSArray of messages to be marked as read.
 * @param successBlock A block to be executed when the call completes successfully.
 * @param failureBlock A block to be executed if the call fails.
 */

- (void)performBatchMarkAsReadForMessages:(NSArray *)messages
                                onSuccess:(UAInboxClientSuccessBlock)successBlock
                                onFailure:(UAInboxClientFailureBlock)failureBlock;

/**
 * Cancels all in-flight API requests.
 */
- (void)cancelAllRequests;

/**
 * Clears the last modified time for message list requests.
 */
- (void)clearLastModifiedTime;

/**
 * Builds request to retrieve message list.
 *
 * @return a UAHTTPRequest instance for a message list request.
 */
- (UAHTTPRequest *)requestToRetrieveMessageList;

/**
 * Builds request to delete array of messages.
 *
 * @param messages Array of messages to mark read.
 * @return a UAHTTPRequest instance for a batch delete request.
 */
- (UAHTTPRequest *)requestToPerformBatchDeleteForMessages:(NSArray *)messages;

/**
 * Builds request to mark array of messages read.
 *
 * @param messages Array of messages to mark read.
 * @return a UAHTTPRequest instance for a batch mark read request.
 */
- (UAHTTPRequest *)requestToPerformBatchMarkReadForMessages:(NSArray *)messages;

@end

NS_ASSUME_NONNULL_END
