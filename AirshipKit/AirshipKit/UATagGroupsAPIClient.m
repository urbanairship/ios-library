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


#import "UATagGroupsAPIClient+Internal.h"
#import "UAConfig.h"
#import "UAUtils.h"
#import "UAHTTPRequestEngine+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"

#define kUATagGroupsRetryTimeInitialDelay 60    // 60 seconds
#define kUATagGroupsRetryTimeMultiplier 2
#define kUATagGroupsRetryTimeMaxDelay 300
#define kUAChannelTagGroupsPath @"/api/channels/tags/"
#define kUANamedUserTagsPath @"/api/named_users/tags/"
#define kUATagGroupsAudienceKey @"audience"
#define kUATagGroupsIosChannelKey @"ios_channel"
#define kUATagGroupsNamedUserIdKey @"named_user_id"
#define kUATagGroupsAddKey @"add"
#define kUATagGroupsRemoveKey @"remove"
#define kUATagGroupsResponseObjectWarningsKey @"warnings"
#define kUATagGroupsResponseObjectErrorKey @"error"

@interface UATagGroupsAPIClient()

@property (nonatomic, copy) NSString *urlString;
@property (nonatomic, strong) UAConfig *config;

@end

@implementation UATagGroupsAPIClient

- (instancetype)initWithConfig:(UAConfig *)config {
    self = [super init];
    if (self) {
        self.config = config;
        self.requestEngine = [[UAHTTPRequestEngine alloc] init];
        self.requestEngine.initialDelayIntervalInSeconds = kUATagGroupsRetryTimeInitialDelay;
        self.requestEngine.maxDelayIntervalInSeconds = kUATagGroupsRetryTimeMaxDelay;
        self.requestEngine.backoffFactor = kUATagGroupsRetryTimeMultiplier;
        self.shouldRetryOnConnectionError = YES;
        self.urlString = [NSString stringWithFormat:@"%@", config.deviceAPIURL];
    }
    return self;
}

+ (instancetype)clientWithConfig:(UAConfig *)config {
    return [[self alloc] initWithConfig:config];
}

- (void)cancelAllRequests {
    [self.requestEngine cancelAllRequests];
}

- (void)logSuccessfulTagGroupRequest:(UAHTTPRequest *)request prefix:(NSString *)prefix {
    id warnings;
    id responseObject = [NSJSONSerialization objectWithString:request.responseString];
    if ([responseObject isKindOfClass:[NSDictionary class]]) {
        warnings = responseObject[kUATagGroupsResponseObjectWarningsKey];
    }

    if (warnings) {
        UA_LINFO(@"%@ tag groups update completed successfully with warnings: %@", prefix, warnings);
    } else {
        UA_LINFO(@"%@ tag groups update completed successfully.", prefix);
    }
}

- (void)logFailedTagGroupRequest:(UAHTTPRequest *)request prefix:(NSString *)prefix {
    id error;
    id responseObject = [NSJSONSerialization objectWithString:request.responseString];
    if ([responseObject isKindOfClass:[NSDictionary class]]) {
        error = responseObject[kUATagGroupsResponseObjectErrorKey];
    }

    if (error) {
        UA_LINFO(@"%@ tag groups update failed with error: %@", prefix, error);
    } else {
        UA_LINFO(@"%@ tag groups update failed.", prefix);
    }
}

- (void)updateChannelTags:(NSString *)channelId
                      add:(NSDictionary *)addTags
                   remove:(NSDictionary *)removeTags
                onSuccess:(UATagGroupsAPIClientSuccessBlock)successBlock
                onFailure:(UATagGroupsAPIClientFailureBlock)failureBlock {

    if (!channelId) {
        UA_LERR(@"The channel ID cannot be nil.");
        return;
    }

    if (!addTags.count && !removeTags.count) {
        UA_LERR(@"Both addTags and removeTags cannot be empty.");
        return;
    }

    NSMutableDictionary *audience = [NSMutableDictionary dictionary];
    [audience setValue:channelId forKey:kUATagGroupsIosChannelKey];

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    [payload setValue:audience forKey:kUATagGroupsAudienceKey];

    if (addTags.count) {
        [payload setValue:addTags forKey:kUATagGroupsAddKey];
    }

    if (removeTags.count) {
        [payload setValue:removeTags forKey:kUATagGroupsRemoveKey];
    }

    UA_LTRACE(@"Updating channel tag groups with payload: %@", payload);

    UAHTTPRequest *request = [self requestWithPayload:payload
                                            urlString:[NSString stringWithFormat:@"%@%@", self.urlString, kUAChannelTagGroupsPath]];

    [self.requestEngine runRequest:request succeedWhere:^BOOL(UAHTTPRequest *request) {
        NSInteger status = request.response.statusCode;
        return (BOOL)(status >= 200 && status <= 299);
    } retryWhere:^BOOL(UAHTTPRequest *request) {
        if (self.shouldRetryOnConnectionError) {
            NSInteger status = request.response.statusCode;
            return (BOOL)((status >= 500 && status <= 599) || request.error);
        }
        return NO;
    } onSuccess:^(UAHTTPRequest *request, NSUInteger lastDelay) {
        UA_LTRACE(@"Retrieved channel tag groups response: %@", request.responseString);
        [self logSuccessfulTagGroupRequest:request prefix:@"Channel"];

        if (successBlock) {
            successBlock();
        } else {
            UA_LERR(@"Missing successBlock");
        }
    } onFailure:^(UAHTTPRequest *request, NSUInteger lastDelay) {
        [UAUtils logFailedRequest:request withMessage:@"Updating channel tag groups"];
        [self logFailedTagGroupRequest:request prefix:@"Channel"];

        if (failureBlock) {
            failureBlock(request);
        } else {
            UA_LERR(@"Missing failureBlock");
        }
    }];
}

- (void)updateNamedUserTags:(NSString *)identifier
                        add:(NSDictionary *)addTags
                     remove:(NSDictionary *)removeTags
                  onSuccess:(UATagGroupsAPIClientSuccessBlock)successBlock
                  onFailure:(UATagGroupsAPIClientFailureBlock)failureBlock {

    if (!identifier) {
        UA_LERR(@"The named user ID cannot be nil.");
        return;
    }

    if (!addTags.count && !removeTags.count) {
        UA_LERR(@"Both addTags and removeTags cannot be empty.");
        return;
    }

    NSMutableDictionary *audience = [NSMutableDictionary dictionary];
    [audience setValue:identifier forKey:kUATagGroupsNamedUserIdKey];

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    [payload setValue:audience forKey:kUATagGroupsAudienceKey];

    if (addTags.count) {
        [payload setValue:addTags forKey:kUATagGroupsAddKey];
    }

    if (removeTags.count) {
        [payload setValue:removeTags forKey:kUATagGroupsRemoveKey];
    }

    UA_LTRACE(@"Updating named user tags with payload: %@", payload);

    UAHTTPRequest *request = [self requestWithPayload:payload
                                            urlString:[NSString stringWithFormat:@"%@%@", self.urlString, kUANamedUserTagsPath]];

    [self.requestEngine runRequest:request succeedWhere:^BOOL(UAHTTPRequest *request) {
        NSInteger status = request.response.statusCode;
        return (BOOL)(status >= 200 && status <= 299);
    } retryWhere:^BOOL(UAHTTPRequest *request) {
        if (self.shouldRetryOnConnectionError) {
            NSInteger status = request.response.statusCode;
            return (BOOL)((status >= 500 && status <= 599) || request.error);
        }
        return NO;
    } onSuccess:^(UAHTTPRequest *request, NSUInteger lastDelay) {
        UA_LTRACE(@"Retrieved named user tags response: %@", request.responseString);
        [self logSuccessfulTagGroupRequest:request prefix:@"Named user"];

        if (successBlock) {
            successBlock();
        } else {
            UA_LERR(@"Missing successBlock");
        }
    } onFailure:^(UAHTTPRequest *request, NSUInteger lastDelay) {
        [UAUtils logFailedRequest:request withMessage:@"Updating named user tags"];
        [self logFailedTagGroupRequest:request prefix:@"Named user"];

        if (failureBlock) {
            failureBlock(request);
        } else {
            UA_LERR(@"Missing failureBlock");
        }
    }];
}

- (UAHTTPRequest *)requestWithPayload:(NSDictionary *)payload urlString:(NSString *)urlString {

    UAHTTPRequest *request = [UAHTTPRequest requestWithURL:[NSURL URLWithString:urlString]];
    request.HTTPMethod = @"POST";
    request.username = self.config.appKey;
    request.password = self.config.appSecret;
    [request addRequestHeader:@"Accept" value:@"application/vnd.urbanairship+json; version=3;"];
    [request addRequestHeader: @"Content-Type" value: @"application/json"];

    NSString *body = [NSJSONSerialization stringWithObject:payload];
    [request appendBodyData:[body dataUsingEncoding:NSUTF8StringEncoding]];

    return request;
}

@end
