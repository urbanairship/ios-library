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

#import "UAUserAPIClient.h"
#import "UAConfig.h"
#import "UAHTTPRequestEngine+Internal.h"
#import "UAUtils.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "UAUser.h"
#import "UAUserData+Internal.h"


@interface UAUserAPIClient()
@property (nonatomic, strong) UAConfig *config;
@end

@implementation UAUserAPIClient

- (instancetype)initWithConfig:(UAConfig *)config {
    self = [super init];
    if (self) {
        self.config = config;
        self.requestEngine= [[UAHTTPRequestEngine alloc] init];
    }

    return self;
}

- (instancetype)initWithRequestEngine:(UAHTTPRequestEngine *)requestEngine {
    self = [super init];
    if (self) {
        self.requestEngine = requestEngine;
    }
    return self;
}

+ (instancetype)clientWithConfig:(UAConfig *)config {
    return [[self alloc] initWithConfig:config];
}

+ (instancetype)clientWithRequestEngine:(UAHTTPRequestEngine *)requestEngine {
    return [[self alloc] initWithRequestEngine:requestEngine];
}

- (void)createUserWithChannelID:(NSString *)channelID
                      onSuccess:(UAUserAPIClientCreateSuccessBlock)successBlock
                      onFailure:(UAUserAPIClientFailureBlock)failureBlock {

    NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithDictionary:@{@"ua_device_id":[UAUtils deviceID]}];

    if (channelID.length) {
        [payload setObject:@[channelID] forKey:@"ios_channels"];
    }

    UAHTTPRequest *request = [self requestToCreateUserWithPayload:payload];

    [self.requestEngine
     runRequest:request succeedWhere:^(UAHTTPRequest *request) {
         NSInteger status = request.response.statusCode;
         return (BOOL)(status == 201);
     } retryWhere:^(UAHTTPRequest *request) {
         NSInteger status = request.response.statusCode;
         return (BOOL)((status >= 500 && status <= 599) || request.error);
     } onSuccess:^(UAHTTPRequest *request, NSUInteger lastDelay) {

         NSDictionary *result = [NSJSONSerialization objectWithString:request.responseString];

         NSString *username = [result objectForKey:@"user_id"];
         NSString *password = [result objectForKey:@"password"];
         NSString *url = [result objectForKey:@"user_url"];

         UAUserData *data = [UAUserData dataWithUsername:username password:password url:url];

         UA_LTRACE(@"Created user: %@", username);
         if (successBlock) {
             successBlock(data, payload);
         } else {
             UA_LERR(@"missing successBlock");
         }
     } onFailure:^(UAHTTPRequest *request, NSUInteger lastDelay) {
         //[UAUtils logFailedRequest:request withMessage:@"creating user"];
         if (failureBlock) {
             failureBlock(request);
         } else {
             UA_LERR(@"missing failureBlock");
         }
     }];
}

- (void)updateUser:(UAUser *)user
         channelID:(NSString *)channelID
         onSuccess:(UAUserAPIClientUpdateSuccessBlock)successBlock
         onFailure:(UAUserAPIClientFailureBlock)failureBlock {


    NSMutableDictionary *payload = [NSMutableDictionary dictionary];

    if (channelID.length) {
        [payload setValue:@{@"add": @[channelID]} forKey:@"ios_channels"];
    }

    UAHTTPRequest *request = [self requestToUpdateUser:user payload:payload];

    [self.requestEngine runRequest:request succeedWhere:^(UAHTTPRequest *request) {
        NSInteger status = request.response.statusCode;
        return (BOOL)(status == 200 || status == 201);
    } retryWhere:^(UAHTTPRequest *request) {
        NSInteger status = request.response.statusCode;
        return (BOOL)((status >= 500 && status <= 599) || request.error);
    } onSuccess:^(UAHTTPRequest *request, NSUInteger lastDelay) {
        UA_LTRACE(@"User successfully updated.");
        if (successBlock) {
            successBlock();
        } else {
            UA_LERR(@"missing successBlock");
        }
    } onFailure:^(UAHTTPRequest *request, NSUInteger lastDelay) {
        //[UAUtils logFailedRequest:request withMessage:@"updating user"];
        if (failureBlock) {
            failureBlock(request);
        } else {
            UA_LERR(@"missing failureBlock");
        }
    }];
}

- (UAHTTPRequest *)requestToCreateUserWithPayload:(NSDictionary *)payload {
    NSString *urlString = [NSString stringWithFormat:@"%@%@",
                           self.config.deviceAPIURL,
                           @"/api/user/"];

    NSURL *createUrl = [NSURL URLWithString:urlString];

    UAHTTPRequest *request = [UAHTTPRequest requestWithURL:createUrl];
    request.HTTPMethod = @"POST";
    request.username = self.config.appKey;
    request.password = self.config.appSecret;

    [request addRequestHeader:@"Content-Type" value:@"application/json"];
    [request addRequestHeader:@"Accept" value:@"application/vnd.urbanairship+json; version=3;"];

    NSString *body = [NSJSONSerialization stringWithObject:payload];
    [request appendBodyData:[body dataUsingEncoding:NSUTF8StringEncoding]];

    UA_LDEBUG(@"Request to create user with body: %@", body);

    return request;
}

- (UAHTTPRequest *)requestToUpdateUser:(UAUser *)user payload:(NSDictionary *)payload {

    NSString *updateUrlString = [NSString stringWithFormat:@"%@%@%@/",
                                 self.config.deviceAPIURL,
                                 @"/api/user/",
                                 user.username];

    NSURL *updateUrl = [NSURL URLWithString: updateUrlString];

    UAHTTPRequest *request = [UAHTTPRequest requestWithURL:updateUrl];
    request.HTTPMethod = @"POST";
    request.username = user.username;
    request.password = user.password;

    [request addRequestHeader:@"Content-Type" value:@"application/json"];
    [request addRequestHeader:@"Accept" value:@"application/vnd.urbanairship+json; version=3;"];

    NSString *body = [NSJSONSerialization stringWithObject:payload];
    [request appendBodyData:[body dataUsingEncoding:NSUTF8StringEncoding]];

    UA_LTRACE(@"Request to update user with body: %@", body);
    
    return request;
}

- (void)cancelAllRequests {
    [self.requestEngine cancelAllRequests];
}

@end
