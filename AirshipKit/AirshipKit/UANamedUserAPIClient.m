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

#import "UANamedUserAPIClient+Internal.h"
#import "UAConfig.h"
#import "UAUtils.h"
#import "UAHTTPRequestEngine+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"

#define kUANamedUserRetryTimeInitialDelay 60    // 60 seconds
#define kUANamedUserRetryTimeMultiplier 2
#define kUANamedUserRetryTimeMaxDelay 300       // 300 seconds
#define kUANamedUserPath @"/api/named_users"
#define kUANamedUserChannelIDKey @"channel_id"
#define kUANamedUserDeviceTypeKey @"device_type"
#define kUANamedUserIdentifierKey @"named_user_id"

@interface UANamedUserAPIClient()
@property (nonatomic, copy) NSString *urlString;
@property (nonatomic, strong) UAConfig *config;

@end

@implementation UANamedUserAPIClient

- (instancetype)initWithConfig:(UAConfig *)config {
    self = [super init];
    if (self) {
        self.config = config;
        self.requestEngine = [[UAHTTPRequestEngine alloc] init];
        self.requestEngine.initialDelayIntervalInSeconds = kUANamedUserRetryTimeInitialDelay;
        self.requestEngine.maxDelayIntervalInSeconds = kUANamedUserRetryTimeMaxDelay;
        self.requestEngine.backoffFactor = kUANamedUserRetryTimeMultiplier;
        self.shouldRetryOnConnectionError = YES;
        self.urlString = [NSString stringWithFormat:@"%@%@", config.deviceAPIURL, kUANamedUserPath];
    }
    return self;
}

+ (instancetype)clientWithConfig:(UAConfig *)config {
    return [[self alloc] initWithConfig:config];
}


- (void)associate:(NSString *)identifier
        channelID:(NSString *)channelID
        onSuccess:(UANamedUserAPIClientSuccessBlock)successBlock
        onFailure:(UANamedUserAPIClientFailureBlock)failureBlock {

    if (!identifier) {
        UA_LERR(@"The named user ID cannot be nil.");
        return;
    }

    if (!channelID) {
        UA_LERR(@"The channel ID cannot be nil.");
        return;
    }

    UA_LTRACE(@"Associating channel %@ with named user ID: %@", channelID, identifier);

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    [payload setValue:channelID forKey:kUANamedUserChannelIDKey];
    [payload setObject:@"ios" forKey:kUANamedUserDeviceTypeKey];
    [payload setValue:identifier forKey:kUANamedUserIdentifierKey];

    UAHTTPRequest *request = [self requestWithPayload:payload
                              urlString:[NSString stringWithFormat:@"%@%@", self.urlString, @"/associate"]];

    [self.requestEngine runRequest:request succeedWhere:^BOOL(UAHTTPRequest *request) {
        NSInteger status = request.response.statusCode;
        return (BOOL)(status >= 200 && status <= 299);
    } retryWhere:^BOOL(UAHTTPRequest *request) {
        if (self.shouldRetryOnConnectionError) {
            NSInteger status = request.response.statusCode;
            return (BOOL)(((status >= 500 && status <= 599) || request.error));
        }
        return NO;
    } onSuccess:^(UAHTTPRequest *request, NSUInteger lastDelay) {
        NSString *responseString = request.responseString;
        UA_LTRACE(@"Retrieved named user response: %@", responseString);

        if (successBlock) {
            successBlock();
        } else {
            UA_LERR(@"Missing successBlock");
        }
    } onFailure:^(UAHTTPRequest *request, NSUInteger lastDelay) {
       // [UAUtils logFailedRequest:request withMessage:@"Associating named user"];

        if (failureBlock) {
            failureBlock(request);
        } else {
            UA_LERR(@"Missing failureBlock");
        }
    }];
}

- (void)disassociate:(NSString *)channelID
           onSuccess:(UANamedUserAPIClientSuccessBlock)successBlock
           onFailure:(UANamedUserAPIClientFailureBlock)failureBlock {

    if (!channelID) {
        UA_LERR(@"The channel ID cannot be nil.");
        return;
    }

    UA_LTRACE(@"Disassociating channel %@ from named user ID", channelID);

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    [payload setValue:channelID forKey:kUANamedUserChannelIDKey];
    [payload setObject:@"ios" forKey:kUANamedUserDeviceTypeKey];

    UAHTTPRequest *request = [self requestWithPayload:payload
                              urlString:[NSString stringWithFormat:@"%@%@", self.urlString, @"/disassociate"]];

    [self.requestEngine runRequest:request succeedWhere:^BOOL(UAHTTPRequest *request) {
        NSInteger status = request.response.statusCode;
        return (BOOL)(status >= 200 && status <= 299);
    } retryWhere:^BOOL(UAHTTPRequest *request) {
        if (self.shouldRetryOnConnectionError) {
            NSInteger status = request.response.statusCode;
            return (BOOL)(((status >= 500 && status <= 599) || request.error));
        }
        return NO;
    } onSuccess:^(UAHTTPRequest *request, NSUInteger lastDelay) {
        NSString *responseString = request.responseString;
        UA_LTRACE(@"Retrieved named user response: %@", responseString);

        if (successBlock) {
            successBlock();
        } else {
            UA_LERR(@"Missing successBlock");
        }
    } onFailure:^(UAHTTPRequest *request, NSUInteger lastDelay) {
        //[UAUtils logFailedRequest:request withMessage:@"Disassociating named user"];

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
