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
#import "NSJSONSerialization+UAAdditions.h"

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

@end

@implementation UATagGroupsAPIClient

- (instancetype)initWithConfig:(UAConfig *)config session:(UARequestSession *)session {
    self = [super initWithConfig:config session:session];
    if (self) {
        self.urlString = [NSString stringWithFormat:@"%@", config.deviceAPIURL];
    }
    return self;
}

+ (instancetype)clientWithConfig:(UAConfig *)config {
    return [[self alloc] initWithConfig:config session:[UARequestSession sessionWithConfig:config]];
}

+ (instancetype)clientWithConfig:(UAConfig *)config session:(UARequestSession *)session {
    return [[self alloc] initWithConfig:config session:session];
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

    UARequest *request = [self requestWithPayload:payload
                                            urlString:[NSString stringWithFormat:@"%@%@", self.urlString, kUAChannelTagGroupsPath]];

    [self.session dataTaskWithRequest:request retryWhere:^BOOL(NSData * _Nullable data, NSURLResponse * _Nullable response) {
        NSHTTPURLResponse *httpResponse = nil;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            httpResponse = (NSHTTPURLResponse *) response;
        }

        NSInteger status = httpResponse.statusCode;
        return (BOOL)((status >= 500 && status <= 599));
    } completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *httpResponse = nil;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            httpResponse = (NSHTTPURLResponse *) response;
        }

        NSInteger status = httpResponse.statusCode;

        // Failure
        if (status < 200 || status > 299) {
            UA_LTRACE(@"Failed to update channel tags with status: %ld", (long)status);
            failureBlock(status);
            return;
        }

        // Success
        UA_LTRACE(@"Updated channel tags with status: %ld", (long)status);
        successBlock();

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

    UARequest *request = [self requestWithPayload:payload
                                            urlString:[NSString stringWithFormat:@"%@%@", self.urlString, kUANamedUserTagsPath]];

    [self.session dataTaskWithRequest:request retryWhere:^BOOL(NSData * _Nullable data, NSURLResponse * _Nullable response) {
        NSHTTPURLResponse *httpResponse = nil;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            httpResponse = (NSHTTPURLResponse *) response;
        }

        NSInteger status = httpResponse.statusCode;
        return (BOOL)(status >= 500 && status <= 599);
    } completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *httpResponse = nil;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            httpResponse = (NSHTTPURLResponse *) response;
        }

        NSInteger status = httpResponse.statusCode;

        // Failure
        if (status < 200 || status > 299) {
            UA_LTRACE(@"Failed to update named user tags with status: %ld", (long)status);
            failureBlock(status);
            return;
        }

        // Success
        UA_LTRACE(@"Updated named user tags with status: %ld", (long)status);
        successBlock();
    }];
}

- (UARequest *)requestWithPayload:(NSDictionary *)payload urlString:(NSString *)urlString {
    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder *builder) {
        builder.URL = [NSURL URLWithString:urlString];
        builder.method = @"POST";
        builder.username = self.config.appKey;
        builder.password = self.config.appSecret;
        builder.body = [NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingPrettyPrinted error:nil];
        [builder setValue:@"application/vnd.urbanairship+json; version=3;" forHeader:@"Accept"];
        [builder setValue:@"application/json" forHeader:@"Content-Type"];
    }];

    return request;
}

@end
