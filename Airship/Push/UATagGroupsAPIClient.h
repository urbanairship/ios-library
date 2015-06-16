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
 * A block called when tag groups update succeeded.
 */
typedef void (^UATagGroupsAPIClientSuccessBlock)();

/**
 * A block called when tag groups update failed.
 *
 * @param request The request that failed.
 */
typedef void (^UATagGroupsAPIClientFailureBlock)(UAHTTPRequest *request);

/**
 * A high level abstraction for performing tag group operations.
 */
@interface UATagGroupsAPIClient : NSObject

/**
 * Factory method to create a UATagGroupsAPIClient.
 *
 * @param config The Urban Airship config.
 * @return UATagGroupsAPIClient instance.
 */
+ (instancetype)clientWithConfig:(UAConfig *)config;

/**
 * Update the channel tag group.
 *
 * @param channelId The channel ID string.
 * @param addTags The dictionary of tag group ID to an array of tags.
 * @param removeTags The dictionary of tag group ID to an array of tags.
 * @param successBlock A UATagGroupsAPIClientSuccessBlock that will be called if
 *        the named user tags updated successfully.
 * @param failureBlock A UATagGroupsAPIClientFailureBlock that will be called if
 *        the named user tags update was unsuccessful.
 */
- (void)updateChannelTags:(NSString *)channelId
                      add:(NSDictionary *)addTags
                   remove:(NSDictionary *)removeTags
                onSuccess:(UATagGroupsAPIClientSuccessBlock)successBlock
                onFailure:(UATagGroupsAPIClientFailureBlock)failureBlock;

/**
 * Update the named user tags.
 *
 * @param identifier The named user ID string.
 * @param addTags The dictionary of tag group ID to an array of tags.
 * @param removeTags The dictionary of tag group ID to an array of tags.
 * @param successBlock A UATagGroupsAPIClientSuccessBlock that will be called if
 *        the named user tags updated successfully.
 * @param failureBlock A UATagGroupsAPIClientFailureBlock that will be called if
 *        the named user tags update was unsuccessful.
 */
- (void)updateNamedUserTags:(NSString *)identifier
                        add:(NSDictionary *)addTags
                     remove:(NSDictionary *)removeTags
                  onSuccess:(UATagGroupsAPIClientSuccessBlock)successBlock
                  onFailure:(UATagGroupsAPIClientFailureBlock)failureBlock;

/**
 * Cancel all current and pending requests.
 *
 * Note: This could prevent the onSuccess and onFailure callbacks from being triggered
 * in any current requests.
 */
- (void)cancelAllRequests;

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
