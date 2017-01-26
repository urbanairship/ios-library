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
@class UATagGroupsMutation;

NS_ASSUME_NONNULL_BEGIN

/**
 * A high level abstraction for performing tag group operations.
 */
@interface UATagGroupsAPIClient : UAAPIClient

/**
 * Factory method to create a UATagGroupsAPIClient.
 *
 * @param config The Urban Airship config.
 * @return UATagGroupsAPIClient instance.
 */
+ (instancetype)clientWithConfig:(UAConfig *)config;

/**
 * Factory method to create a UATagGroupsAPIClient.
 *
 * @param config The Urban Airship config.
 * @param session The request session.
 * @return UATagGroupsAPIClient instance.
 */
+ (instancetype)clientWithConfig:(UAConfig *)config session:(UARequestSession *)session;

/**
 * Update the channel tag group.
 *
 * @param channelId The channel ID string.
 * @param mutation The tag groups changes.
 * @param completionHandler The completion handler with the status code.
 */
- (void)updateChannel:(NSString *)channelId
    tagGroupsMutation:(UATagGroupsMutation *)mutation
    completionHandler:(void (^)(NSUInteger status))completionHandler;

/**
 * Update the named user tags.
 *
 * @param identifier The named user ID string.
 * @param mutation The tag groups changes.
 * @param completionHandler The completion handler with the status code.
 */
- (void)updateNamedUser:(NSString *)identifier
      tagGroupsMutation:(UATagGroupsMutation *)mutation
      completionHandler:(void (^)(NSUInteger status))completionHandler;

@end

NS_ASSUME_NONNULL_END
