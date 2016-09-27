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

#import "UAChannelAPIClient+Internal.h"
#import "UAHTTPRequestEngine+Internal.h"
#import "UAChannelRegistrationPayload+Internal.h"
#import "UAHTTPConnectionOperation+Internal.h"
#import "UAConfig.h"
#import "UAUtils.h"
#import "UAirship.h"
#import "UAAnalytics+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"


#define kUAChannelRetryTimeInitialDelay 60
#define kUAChannelRetryTimeMultiplier 2
#define kUAChannelRetryTimeMaxDelay 300
#define kUAChannelCreateLocation @"/api/channels/"

@interface UAChannelAPIClient()
@property (nonatomic, strong) UAConfig *config;
@end

@implementation UAChannelAPIClient

- (instancetype)initWithConfig:(UAConfig *)config {
    self = [super init];
    if (self) {
        self.config = config;
        self.requestEngine = [[UAHTTPRequestEngine alloc] init];
        self.requestEngine.initialDelayIntervalInSeconds = kUAChannelRetryTimeInitialDelay;
        self.requestEngine.maxDelayIntervalInSeconds = kUAChannelRetryTimeMaxDelay;
        self.requestEngine.backoffFactor = kUAChannelRetryTimeMultiplier;
        self.shouldRetryOnConnectionError = YES;
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

+ (instancetype)clientWithConfig:(UAConfig *)config {
    return [[self alloc] initWithConfig:config];
}


- (void)cancelAllRequests {
    [self.requestEngine cancelAllRequests];
}

- (void)createChannelWithPayload:(UAChannelRegistrationPayload *)payload
                      onSuccess:(UAChannelAPIClientCreateSuccessBlock)successBlock
                      onFailure:(UAChannelAPIClientFailureBlock)failureBlock {

    UA_LTRACE(@"Creating channel with JSON payload %@.", [[NSString alloc] initWithData:[payload asJSONData] encoding:NSUTF8StringEncoding]);



    UAHTTPRequest *request = [self requestToCreateChannelWithPayload:payload];

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
        NSDictionary *jsonResponse = [NSJSONSerialization objectWithString:responseString];
        UA_LTRACE(@"Retrieved channel response: %@", responseString);
        NSInteger status = request.response.statusCode;

        BOOL existing = NO;
        // 200 means channel previously existed, while 201 means newly created channel
        if (status == 200) {
            existing = YES;
        }

        // Get the channel ID from the request
        NSString *channelID = [jsonResponse valueForKey:@"channel_id"];

        // Channel location from the request
        NSString *channelLocation = [request.response.allHeaderFields valueForKey:@"Location"];
        if (successBlock) {
            successBlock(channelID, channelLocation, existing);
        } else {
            UA_LERR(@"missing successBlock");
        }

        // Send analytics events
        [[UAirship shared].analytics sendWithDelay:0];

    } onFailure:^(UAHTTPRequest *request, NSUInteger lastDelay) {
        [UAUtils logFailedRequest:request withMessage:@"Creating channel"];

        if (failureBlock) {
            failureBlock(request);
        } else {
            UA_LERR(@"missing failureBlock");
        }
    }];
}

- (void)updateChannelWithLocation:(NSString *)channelLocation
                      withPayload:(UAChannelRegistrationPayload *)payload
                        onSuccess:(UAChannelAPIClientUpdateSuccessBlock)successBlock
                        onFailure:(UAChannelAPIClientFailureBlock)failureBlock {

    if (!channelLocation) {
        UA_LERR(@"Unable to update a channel with a nil channel location.");
        return;
    }

    UA_LTRACE(@"Updating channel at location %@ with JSON payload %@.", channelLocation, [[NSString alloc] initWithData:[payload asJSONData] encoding:NSUTF8StringEncoding]);

    UAHTTPRequest *request = [self requestToUpdateWithChannelLocation:channelLocation payload:payload];

    [self.requestEngine runRequest:request succeedWhere:^BOOL(UAHTTPRequest *request) {
        NSInteger status = request.response.statusCode;
        return (BOOL)(status == 200 || status == 201);
    } retryWhere:^BOOL(UAHTTPRequest *request) {
        if (self.shouldRetryOnConnectionError) {
            NSInteger status = request.response.statusCode;
            return (BOOL)((status >= 500 && status <= 599) || request.error);
        }
        return NO;
    } onSuccess:^(UAHTTPRequest *request, NSUInteger lastDelay) {
        UA_LTRACE(@"Retrieved channel response: %@", request.responseString);

        if (successBlock) {
            successBlock();
        } else {
            UA_LERR(@"missing successBlock");
        }
    } onFailure:^(UAHTTPRequest *request, NSUInteger lastDelay) {
        [UAUtils logFailedRequest:request withMessage:@"Updating channel"];

        if (failureBlock) {
            failureBlock(request);
        } else {
            UA_LERR(@"missing failureBlock");
        }
    }];
}

/**
 * Creates an UAHTTPRequest for updating a channel.
 *
 * @param location The channel location
 * @param payload The payload to update the channel.
 * @return A UAHTTPRequest request.
 */
- (UAHTTPRequest *)requestToUpdateWithChannelLocation:(NSString *)location payload:(UAChannelRegistrationPayload *)payload {

    UAHTTPRequest *request = [UAHTTPRequest requestWithURL:[NSURL URLWithString:location]];
    request.HTTPMethod = @"PUT";
    request.username = self.config.appKey;
    request.password = self.config.appSecret;

    [request addRequestHeader:@"Accept" value:@"application/vnd.urbanairship+json; version=3;"];
    [request addRequestHeader: @"Content-Type" value: @"application/json"];
    [request appendBodyData:[payload asJSONData]];

    return request;
}

/**
 * Creates an UAHTTPRequest to create a channel.
 *
 * @param payload The payload to update the channel.
 * @return A UAHTTPRequest request.
 */
- (UAHTTPRequest *)requestToCreateChannelWithPayload:(UAChannelRegistrationPayload *)payload {
    NSString *urlString = [NSString stringWithFormat:@"%@%@", self.config.deviceAPIURL, kUAChannelCreateLocation];

    UAHTTPRequest *request = [UAHTTPRequest requestWithURL:[NSURL URLWithString:urlString]];
    request.HTTPMethod = @"POST";
    request.username = self.config.appKey;
    request.password = self.config.appSecret;

    [request addRequestHeader:@"Accept" value:@"application/vnd.urbanairship+json; version=3;"];
    [request addRequestHeader: @"Content-Type" value: @"application/json"];
    [request appendBodyData:[payload asJSONData]];

    return request;
}

@end
