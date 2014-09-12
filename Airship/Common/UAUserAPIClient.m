/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

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
#import "UAirship.h"
#import "UAConfig.h"
#import "UAHTTPRequestEngine.h"
#import "UAUtils.h"
#import "NSJSONSerialization+UAAdditions.h"

@interface UAUserAPIClient()
@property (nonatomic, strong) UAHTTPRequestEngine *requestEngine;
@end

@implementation UAUserAPIClient

- (instancetype)init {
    self = [super init];
    if (self) {
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

+ (instancetype)client {
    return [[self alloc] init];
}

+ (instancetype)clientWithRequestEngine:(UAHTTPRequestEngine *)requestEngine {
    return [[self alloc] initWithRequestEngine:requestEngine];
}

- (void)createUserWithChannelID:(NSString *)channelID
                    deviceToken:(NSString *)deviceToken
                      onSuccess:(UAUserAPIClientCreateSuccessBlock)successBlock
                      onFailure:(UAUserAPIClientFailureBlock)failureBlock {

    NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithDictionary:@{@"ua_device_id":[UAUtils deviceID]}];

    if (channelID.length) {
        [payload setObject:@[channelID] forKey:@"ios_channels"];
    } else if (deviceToken.length) {
        [payload setObject:@[deviceToken] forKey:@"device_tokens"];
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
         [UAUtils logFailedRequest:request withMessage:@"creating user"];
         if (failureBlock) {
             failureBlock(request);
         } else {
             UA_LERR(@"missing failureBlock");
         }
     }];
}

- (void)updateUser:(NSString *)username
       deviceToken:(NSString *)deviceToken
         channelID:(NSString *)channelID
         onSuccess:(UAUserAPIClientUpdateSuccessBlock)successBlock
         onFailure:(UAUserAPIClientFailureBlock)failureBlock {



    NSMutableDictionary *payload = [NSMutableDictionary dictionary];

    if (channelID.length) {
        [payload setValue:@{@"add": @[channelID]} forKey:@"ios_channels"];

        if (deviceToken.length) {
            [payload setValue:@{@"remove": @[deviceToken]} forKey:@"device_tokens"];
        }
    } else if (deviceToken.length) {
        [payload setValue:@{@"add": @[deviceToken]} forKey:@"device_tokens"];
    }

    UAHTTPRequest *request = [self requestToUpdateUserWithPayload:payload
                                                 forUsername:username];

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
        [UAUtils logFailedRequest:request withMessage:@"updating user"];
        if (failureBlock) {
            failureBlock(request);
        } else {
            UA_LERR(@"missing failureBlock");
        }
    }];
}

- (UAHTTPRequest *)requestToCreateUserWithPayload:(NSDictionary *)payload {
    NSString *urlString = [NSString stringWithFormat:@"%@%@",
                           [UAirship shared].config.deviceAPIURL,
                           @"/api/user/"];

    NSURL *createUrl = [NSURL URLWithString:urlString];
    UAHTTPRequest *request = [UAUtils UAHTTPRequestWithURL:createUrl method:@"POST"];
    [request addRequestHeader:@"Content-Type" value:@"application/json"];
    [request addRequestHeader:@"Accept" value:@"application/vnd.urbanairship+json; version=3;"];

    NSString *body = [NSJSONSerialization stringWithObject:payload];
    [request appendBodyData:[body dataUsingEncoding:NSUTF8StringEncoding]];

    UA_LDEBUG(@"Request to create user with body: %@", body);

    return request;
}

- (UAHTTPRequest *)requestToUpdateUserWithPayload:(NSDictionary *)payload
                                 forUsername:(NSString *)username {

    NSString *updateUrlString = [NSString stringWithFormat:@"%@%@%@/",
                                 [UAirship shared].config.deviceAPIURL,
                                 @"/api/user/",
                                 username];

    NSURL *updateUrl = [NSURL URLWithString: updateUrlString];

    // Now do the user update, and pass out "master list" of deviceTokens back to the server
    UAHTTPRequest *request = [UAUtils UAHTTPUserRequestWithURL:updateUrl method:@"POST"];

    [request addRequestHeader:@"Content-Type" value:@"application/json"];
    [request addRequestHeader:@"Accept" value:@"application/vnd.urbanairship+json; version=3;"];

    NSString *body = [NSJSONSerialization stringWithObject:payload];
    [request appendBodyData:[body dataUsingEncoding:NSUTF8StringEncoding]];

    UA_LTRACE(@"Request to update user with body: %@", body);
    
    return request;
}

@end
