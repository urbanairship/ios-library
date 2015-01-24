/*
 Copyright 2009-2015 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
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

#import "UANamedUserAPIClient.h"
#import "UAirship.h"
#import "UAConfig.h"
#import "UAUtils.h"
#import "UAHTTPRequestEngine.h"
#import "NSJSONSerialization+UAAdditions.h"

#define kUANamedUserRetryTimeInitialDelay 60
#define kUANamedUserRetryTimeMultiplier 2
#define kUANamedUserRetryTimeMaxDelay 300
#define kUANamedUserPath @"/api/named_users"
#define kUANamedUserChannelIDKey @"channel_id"
#define kUANamedUserDeviceTypeKey @"device_type"
#define kUANamedUserIdentifierKey @"named_user_id"

@interface UANamedUserAPIClient()
@property (nonatomic, strong) UAHTTPRequestEngine *requestEngine;
@property (nonatomic, copy) NSString *urlString;
@end

@implementation UANamedUserAPIClient

- (instancetype)init {
    self = [super init];
    if (self) {
        self.requestEngine = [[UAHTTPRequestEngine alloc] init];
        self.requestEngine.initialDelayIntervalInSeconds = kUANamedUserRetryTimeInitialDelay;
        self.requestEngine.maxDelayIntervalInSeconds = kUANamedUserRetryTimeMaxDelay;
        self.requestEngine.backoffFactor = kUANamedUserRetryTimeMultiplier;
        self.shouldRetryOnConnectionError = YES;
        self.urlString = [NSString stringWithFormat:@"%@%@", [UAirship shared].config.deviceAPIURL, kUANamedUserPath];
    }
    return self;
}

- (instancetype)initWithRequestEngine:(UAHTTPRequestEngine *)requestEngine {
    self = [super init];
    if (self) {
        self.requestEngine = requestEngine;
        self.shouldRetryOnConnectionError = YES;
    }
    return self;
}

+ (instancetype)client {
    return [[self alloc] init];
}

+ (instancetype)clientWithRequestEngine:(UAHTTPRequestEngine *)requestEngine {
    return [[self alloc] initWithRequestEngine:requestEngine];
}

- (void)associate:(NSString *)identifier
        channelID:(NSString *)channelID
        onSuccess:(UANamedUserAPIClientSuccessBlock)successBlock
        onFailure:(UANamedUserAPIClientFailureBlock)failureBlock {

    UA_LTRACE(@"Associating channel %@ with named user ID: %@", channelID, identifier);

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    [payload setObject:channelID forKey:kUANamedUserChannelIDKey];
    [payload setObject:@"ios" forKey:kUANamedUserDeviceTypeKey];
    [payload setObject:identifier forKey:kUANamedUserIdentifierKey];

    UAHTTPRequest *request = [self requestWithPayload:payload
                              urlString:[NSString stringWithFormat:@"%@%@", self.urlString, @"/associate"]];

    [self.requestEngine runRequest:request succeedWhere:^BOOL(UAHTTPRequest *request) {
        NSInteger status = request.response.statusCode;
        return (BOOL)(status == 200 || status == 201);
    } retryWhere:^BOOL(UAHTTPRequest *request) {
        if (self.shouldRetryOnConnectionError) {
            NSInteger status = request.response.statusCode;
            return (BOOL)(((status >= 500 && status <= 599 && status != 501) || request.error));
        }
        return NO;
    } onSuccess:^(UAHTTPRequest *request, NSUInteger lastDelay) {
        NSString *responseString = request.responseString;
        UA_LTRACE(@"Retrieved named user response: %@", responseString);

        if (successBlock) {
            successBlock();
        } else {
            UA_LERR(@"missing successBlock");
        }
    }onFailure:^(UAHTTPRequest *request, NSUInteger lastDelay) {
        [UAUtils logFailedRequest:request withMessage:@"Associating named user"];

        if (failureBlock) {
            failureBlock(request);
        } else {
            UA_LERR(@"missing failureBlock");
        }
    }];
}

- (void)disassociate:(NSString *)channelID
           onSuccess:(UANamedUserAPIClientSuccessBlock)successBlock
           onFailure:(UANamedUserAPIClientFailureBlock)failureBlock {

    UA_LTRACE(@"Disassociating channel %@ from named user ID", channelID);

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    [payload setObject:channelID forKey:kUANamedUserChannelIDKey];
    [payload setObject:@"ios" forKey:kUANamedUserDeviceTypeKey];

    UAHTTPRequest *request = [self requestWithPayload:payload
                              urlString:[NSString stringWithFormat:@"%@%@", self.urlString, @"/disassociate"]];

    [self.requestEngine runRequest:request succeedWhere:^BOOL(UAHTTPRequest *request) {
        NSInteger status = request.response.statusCode;
        return (BOOL)(status == 200 || status == 201);
    } retryWhere:^BOOL(UAHTTPRequest *request) {
        if (self.shouldRetryOnConnectionError) {
            // TODO: test retry when response is nil
            NSInteger status = request.response.statusCode;
            return (BOOL)(((status >= 500 && status <= 599 && status != 501) || request.error));
        }
        return NO;
    } onSuccess:^(UAHTTPRequest *request, NSUInteger lastDelay) {
        NSString *responseString = request.responseString;
        UA_LTRACE(@"Retrieved named user response: %@", responseString);

        if (successBlock) {
            successBlock();
        } else {
            UA_LERR(@"missing successBlock");
        }
    }onFailure:^(UAHTTPRequest *request, NSUInteger lastDelay) {
        [UAUtils logFailedRequest:request withMessage:@"Disassociating named user"];

        if (failureBlock) {
            failureBlock(request);
        } else {
            UA_LERR(@"missing failureBlock");
        }
    }];
}

- (UAHTTPRequest *)requestWithPayload:(NSDictionary *)payload urlString:(NSString *)urlString {

    UAHTTPRequest *request = [UAUtils UAHTTPRequestWithURL:[NSURL URLWithString:urlString] method:@"POST"];
    [request addRequestHeader:@"Accept" value:@"application/vnd.urbanairship+json; version=3;"];
    [request addRequestHeader: @"Content-Type" value: @"application/json"];

    NSString *body = [NSJSONSerialization stringWithObject:payload];
    [request appendBodyData:[body dataUsingEncoding:NSUTF8StringEncoding]];

    return request;
}

@end
