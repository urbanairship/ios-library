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

#import "UAUserAPIClient+Internal.h"
#import "UAConfig.h"
#import "UAUtils.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "UAUser.h"
#import "UAUserData+Internal.h"

@implementation UAUserAPIClient

+ (instancetype)clientWithConfig:(UAConfig *)config session:(UARequestSession *)session {
    return [[self alloc] initWithConfig:config session:session];
}

+ (instancetype)clientWithConfig:(UAConfig *)config {
    return [UAUserAPIClient clientWithConfig:config session:[UARequestSession sessionWithConfig:config]];
}

- (void)createUserWithChannelID:(NSString *)channelID
                      onSuccess:(UAUserAPIClientCreateSuccessBlock)successBlock
                      onFailure:(UAUserAPIClientFailureBlock)failureBlock {

    NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithDictionary:@{@"ua_device_id":[UAUtils deviceID]}];

    if (channelID.length) {
        [payload setObject:@[channelID] forKey:@"ios_channels"];
    }

    UARequest *request = [self requestToCreateUserWithPayload:payload];


    [self.session dataTaskWithRequest:request retryWhere:^BOOL(NSData * _Nullable data, NSURLResponse * _Nullable response) {
        NSHTTPURLResponse *httpResponse = nil;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            httpResponse = (NSHTTPURLResponse *) response;
        }

        if (httpResponse.statusCode >= 500 && httpResponse.statusCode <= 599) {
            return YES;
        }

        return NO;
    } completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *httpResponse = nil;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            httpResponse = (NSHTTPURLResponse *) response;
        }

        NSUInteger status = httpResponse.statusCode;

        // Failure
        if (status != 201) {
            UA_LTRACE(@"User creation failed with status: %ld error: %@", (unsigned long)status, error);
            failureBlock(status);
            return;
        }

        // Success
        NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];

        NSString *username = [jsonResponse objectForKey:@"user_id"];
        NSString *password = [jsonResponse objectForKey:@"password"];
        NSString *url = [jsonResponse objectForKey:@"user_url"];

        UAUserData *userData = [UAUserData dataWithUsername:username password:password url:url];

        UA_LTRACE(@"Created user: %@", username);
        successBlock(userData, payload);

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

    UARequest *request = [self requestToUpdateUser:user payload:payload];

    [self.session dataTaskWithRequest:request retryWhere:^BOOL(NSData * _Nullable data, NSURLResponse * _Nullable response) {
        NSHTTPURLResponse *httpResponse = nil;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            httpResponse = (NSHTTPURLResponse *) response;
        }

        if (httpResponse.statusCode >= 500 && httpResponse.statusCode <= 599) {
            return YES;
        }

        return NO;
    } completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *httpResponse = nil;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            httpResponse = (NSHTTPURLResponse *) response;
        }

        NSUInteger status = httpResponse.statusCode;

        // Failure
        if (status != 200 && status != 201) {
            UA_LTRACE(@"User update failed with status: %ld error: %@", (unsigned long)status, error);
            failureBlock(status);

            return;
        }

        // Success
        UA_LTRACE(@"Successfully updated user: %@", user);
        successBlock();
    }];
}

- (UARequest *)requestToCreateUserWithPayload:(NSDictionary *)payload {
    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder * _Nonnull builder) {
        NSString *createURLString = [NSString stringWithFormat:@"%@%@",
                               self.config.deviceAPIURL,
                               @"/api/user/"];

        builder.URL = [NSURL URLWithString:createURLString];
        builder.method = @"POST";
        builder.username = self.config.appKey;
        builder.password = self.config.appSecret;

        [builder setValue:@"application/json" forHeader:@"Content-Type"];
        [builder setValue:@"application/vnd.urbanairship+json; version=3;" forHeader:@"Accept"];

        builder.body = [NSJSONSerialization dataWithJSONObject:payload
                                                       options:0
                                                         error:nil];

        UA_LDEBUG(@"Request to create user with body: %@", builder.body);
    }];

    return request;
}

- (UARequest *)requestToUpdateUser:(UAUser *)user payload:(NSDictionary *)payload {
    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder * _Nonnull builder) {
        NSString *updateURLString = [NSString stringWithFormat:@"%@%@%@/",
                                     self.config.deviceAPIURL,
                                     @"/api/user/",
                                     user.username];

        builder.URL = [NSURL URLWithString:updateURLString];
        builder.method = @"POST";
        builder.username = user.username;
        builder.password = user.password;

        [builder setValue:@"application/json" forHeader:@"Content-Type"];
        [builder setValue:@"application/vnd.urbanairship+json; version=3;" forHeader:@"Accept"];

        builder.body = [NSJSONSerialization dataWithJSONObject:payload
                                                       options:0
                                                         error:nil];

        UA_LDEBUG(@"Request to update user with body: %@", builder.body);
    }];

    return request;
}

@end
