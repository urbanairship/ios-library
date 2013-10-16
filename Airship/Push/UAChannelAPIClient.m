/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

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

#import "UAChannelAPIClient.h"
#import "UAHTTPConnectionOperation.h"
#import "UAirship.h"
#import "UAConfig.h"
#import "UAUtils.h"
#import "NSJSONSerialization+UAAdditions.h"


#define kUAChannelRetryTimeInitialDelay 60
#define kUAChannelRetryTimeMultiplier 2
#define kUAChannelRetryTimeMaxDelay 300
#define kUAChannelURLBase @"/api/channels/"

@interface UAChannelAPIClient()
@property(nonatomic, strong) UAHTTPRequestEngine *requestEngine;
@property(nonatomic, strong) UAChannelRegistrationPayload *lastSuccessfulPayload;
@property(nonatomic, strong) UAChannelRegistrationPayload *pendingPayload;
@end

@implementation UAChannelAPIClient

- (id)init {
    self = [super init];
    if (self) {
        self.requestEngine = [[UAHTTPRequestEngine alloc] init];
        self.requestEngine.initialDelayIntervalInSeconds = kUAChannelRetryTimeInitialDelay;
        self.requestEngine.maxDelayIntervalInSeconds = kUAChannelRetryTimeMaxDelay;
        self.requestEngine.backoffFactor = kUAChannelRetryTimeMultiplier;
    }
    return self;
}

-(void)createChannelWithPayload:(UAChannelRegistrationPayload *)payload
                      onSuccess:(UAChannelAPIClientCreateSuccessBlock)successBlock
                      onFailure:(UAChannelAPIClientFailureBlock)failureBlock {

    // There should never be a create request with a update request.
    [self.requestEngine cancelAllRequests];

    UAHTTPRequest *request = [self requestToCreateWithPayload:payload];

    [self.requestEngine runRequest:request succeedWhere:^BOOL(UAHTTPRequest *request) {
        NSInteger status = request.response.statusCode;
        return (BOOL)(status == 200 || status == 201);
    } retryWhere:^BOOL(UAHTTPRequest *request) {
        NSInteger status = request.response.statusCode;
        return (BOOL)(((status >= 500 && status <= 599 && status != 501)|| request.error));
    } onSuccess:^(UAHTTPRequest *request, NSUInteger lastDelay) {

        NSString *responseString = request.responseString;
        NSDictionary *jsonResponse = [NSJSONSerialization objectWithString:responseString];
        UA_LTRACE(@"Retrieved channel response: %@", responseString);


        // Get the channel id from the request
        NSString *channelID = [jsonResponse valueForKey:@"channel_id"];

        if (successBlock) {
            successBlock(channelID);
        } else {
            UA_LERR(@"missing successBlock");
        }
    } onFailure:^(UAHTTPRequest *request, NSUInteger lastDelay) {
        if (failureBlock) {
            failureBlock(request);
        } else {
            UA_LERR(@"missing failureBlock");
        }
    }];
}

-(void)updateChannel:(NSString *)channelID
         withPayload:(UAChannelRegistrationPayload *)payload
           onSuccess:(UAChannelAPIClientUpdateSuccessBlock)successBlock
           onFailure:(UAChannelAPIClientFailureBlock)failureBlock {

    if (!channelID) {
        UA_LERR(@"Unable to update a nil channel id.");
        return;
    }

    if (![self shouldSendUpdateWithPayload:payload]) {
        UA_LDEBUG(@"Ignoring duplicate update request.");
        return;
    }

    UAChannelRegistrationPayload *payloadCopy = [payload copy];
    // There should never be a create request with a update request.
    [self.requestEngine cancelAllRequests];

    //synchronize here since we're messing with the registration cache
    //the success/failure blocks below will be triggered on the main thread
    @synchronized(self) {
        self.pendingPayload = payloadCopy;
    }

    UAHTTPRequest *request = [self requestToUpdateWithChannelID:channelID payload:payload];

    [self.requestEngine runRequest:request succeedWhere:^BOOL(UAHTTPRequest *request) {
        NSInteger status = request.response.statusCode;
        return (BOOL)(status == 200 || status == 201);
    } retryWhere:^BOOL(UAHTTPRequest *request) {
        NSInteger status = request.response.statusCode;
        return (BOOL)(((status >= 500 && status <= 599)|| request.error));
    } onSuccess:^(UAHTTPRequest *request, NSUInteger lastDelay) {
        UA_LTRACE(@"Retrieved channel response: %@", request.responseString);

        //clear the pending cache,  update last successful cache
        self.pendingPayload = nil;
        self.lastSuccessfulPayload = payloadCopy;

        if (successBlock) {
            successBlock();
        } else {
            UA_LERR(@"missing successBlock");
        }
    } onFailure:^(UAHTTPRequest *request, NSUInteger lastDelay) {
        //clear the pending cache
        self.pendingPayload = nil;

        if (failureBlock) {
            failureBlock(request);
        } else {
            UA_LERR(@"missing failureBlock");
        }
    }];
}

- (BOOL)shouldSendUpdateWithPayload:(UAChannelRegistrationPayload *)data {
    return !([self.pendingPayload isEqualToPayload:data]
             || [self.lastSuccessfulPayload isEqualToPayload:data]);
}

- (UAHTTPRequest *)requestToUpdateWithChannelID:(NSString *)channelID payload:(UAChannelRegistrationPayload *)payload {
    NSString *urlString = [NSString stringWithFormat:@"%@%@%@/", [UAirship shared].config.channelAPIURL, kUAChannelURLBase, channelID];
    UAHTTPRequest *request = [UAUtils UAHTTPRequestWithURL:[NSURL URLWithString:urlString] method:@"PUT"];

    [request addRequestHeader:@"Accept" value:@"application/vnd.urbanairship+json; version=3;"];

    if (payload) {
        [request addRequestHeader: @"Content-Type" value: @"application/json"];
        [request appendBodyData:[payload asJSONData]];
    }

    return request;
}

- (UAHTTPRequest *)requestToCreateWithPayload:(UAChannelRegistrationPayload *)payload {
    NSString *urlString = [NSString stringWithFormat:@"%@%@", [UAirship shared].config.channelAPIURL, kUAChannelURLBase];
    UAHTTPRequest *request = [UAUtils UAHTTPRequestWithURL:[NSURL URLWithString:urlString] method:@"POST"];

    [request addRequestHeader:@"Accept" value:@"application/vnd.urbanairship+json; version=3;"];

    if (payload) {
        [request addRequestHeader: @"Content-Type" value: @"application/json"];
        [request appendBodyData:[payload asJSONData]];
    }

    return request;
}



@end
