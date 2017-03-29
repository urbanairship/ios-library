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

#import "UAInboxAPIClient+Internal.h"
#import "UAInboxMessage.h"
#import "UAConfig.h"
#import "UAUser.h"
#import "UAUtils.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAirship.h"
#import "UAPush.h"

@interface UAInboxAPIClient()

@property (nonatomic, strong) UAUser *user;
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;

@end

@implementation UAInboxAPIClient

NSString *const UALastMessageListModifiedTime = @"UALastMessageListModifiedTime.%@";

- (instancetype)initWithConfig:(UAConfig *)config session:(UARequestSession *)session user:(UAUser *)user dataStore:(UAPreferenceDataStore *)dataStore {
    self = [super initWithConfig:config session:session];

    if (self) {
        self.user = user;
        self.dataStore = dataStore;
    }

    return self;
}

+ (instancetype)clientWithConfig:(UAConfig *)config session:(UARequestSession *)session user:(UAUser *)user dataStore:(UAPreferenceDataStore *)dataStore {
    return [[UAInboxAPIClient alloc] initWithConfig:config session:session user:user dataStore:dataStore];
}

- (UARequest *)requestToRetrieveMessageList{

    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder * _Nonnull builder) {

        NSString *urlString = [NSString stringWithFormat: @"%@%@%@%@",
                               self.config.deviceAPIURL, @"/api/user/", self.user.username,@"/messages/"];

        NSURL *requestUrl = [NSURL URLWithString: urlString];

        builder.URL = requestUrl;
        builder.method = @"GET";
        builder.username = self.user.username;
        builder.password = self.user.password;

        [builder setValue:[UAirship push].channelID forHeader:kUAChannelIDHeader];

        NSString *lastModified = [self.dataStore stringForKey:[NSString stringWithFormat:UALastMessageListModifiedTime, self.user.username]];
        if (lastModified) {
            [builder setValue:lastModified forHeader:@"If-Modified-Since"];
        }

        UA_LTRACE(@"Request to retrieve message list: %@", urlString);
    }];

    return request;
}

- (UARequest *)requestToPerformBatchDeleteForMessages:(NSArray *)messages {
    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder * _Nonnull builder) {
        NSDictionary *data;
        NSArray *updateMessageURLs = [messages valueForKeyPath:@"messageURL.absoluteString"];

        data = @{@"delete" : updateMessageURLs};

        NSData* body = [NSJSONSerialization dataWithJSONObject:data
                                                       options:0
                                                         error:nil];

        NSString *urlString = [NSString stringWithFormat:@"%@%@%@%@",
                               self.config.deviceAPIURL,
                               @"/api/user/",
                               self.user.username,
                               @"/messages/delete/"];

        builder.URL = [NSURL URLWithString:urlString];
        builder.method = @"POST";
        builder.username = self.user.username;
        builder.password = self.user.password;
        builder.body = body;
        [builder setValue:@"application/vnd.urbanairship+json; version=3;" forHeader:@"Accept"];
        [builder setValue:@"application/json" forHeader:@"Content-Type"];
        [builder setValue:[UAirship push].channelID forHeader:kUAChannelIDHeader ];

        UA_LTRACE(@"Request to perform batch delete: %@  body: %@", urlString, body);

    }];

    return request;
}

- (UARequest *)requestToPerformBatchMarkReadForMessages:(NSArray *)messages {
    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder * _Nonnull builder) {
        NSDictionary *data;
        NSArray *updateMessageURLs = [messages valueForKeyPath:@"messageURL.absoluteString"];

        data = @{@"mark_as_read" : updateMessageURLs};

        NSData* body = [NSJSONSerialization dataWithJSONObject:data
                                                       options:0
                                                         error:nil];

        NSString *urlString = [NSString stringWithFormat:@"%@%@%@%@",
                               self.config.deviceAPIURL,
                               @"/api/user/",
                               self.user.username,
                               @"/messages/unread/"];

        builder.URL = [NSURL URLWithString:urlString];
        builder.method = @"POST";
        builder.username = self.user.username;
        builder.password = self.user.password;
        builder.body = body;
        [builder setValue:@"application/vnd.urbanairship+json; version=3;" forHeader:@"Accept"];
        [builder setValue:@"application/json" forHeader:@"Content-Type"];
        [builder setValue:[UAirship push].channelID forHeader:kUAChannelIDHeader];

        UA_LTRACE(@"Request to perfom batch mark messages as read: %@ body: %@", urlString, body);
    }];

    return request;
}

- (void)retrieveMessageListOnSuccess:(UAInboxClientMessageRetrievalSuccessBlock)successBlock
                           onFailure:(UAInboxClientFailureBlock)failureBlock {

    UARequest *retrieveRequest = [self requestToRetrieveMessageList];

    [self.session dataTaskWithRequest:retrieveRequest retryWhere:^BOOL(NSData * _Nullable data, NSURLResponse * _Nullable response) {
        return NO;
    } completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *httpResponse = nil;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            httpResponse = (NSHTTPURLResponse *) response;
        }

        // Failure
        if (httpResponse.statusCode != 200  && httpResponse.statusCode != 304) {
            [UAUtils logFailedRequest:retrieveRequest withMessage:@"Retrieve messages failed" withError:error withResponse:httpResponse];
            failureBlock();
            return;
        }

        // 304, no changes
        if (httpResponse.statusCode == 304) {
            successBlock(httpResponse.statusCode, nil);
            return;
        }

        // Missing response body
        if (!data) {
            UA_LTRACE(@"Retrieve messages list missing response body.");
            failureBlock();
            return;
        }

        // Success
        NSArray *messages = nil;
        NSDictionary *headers = httpResponse.allHeaderFields;
        NSString *lastModified = [headers objectForKey:@"Last-Modified"];

        // Parse the response
        NSError *parseError;
        NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        messages = [jsonResponse objectForKey:@"messages"];

        if (!messages) {
            UA_LDEBUG(@"Unable to parse inbox message body: %@ Error: %@", data, parseError);
            failureBlock();
            return;
        }

        UA_LTRACE(@"Retrieved message list with status: %ld jsonResponse: %@", (unsigned long)httpResponse.statusCode, jsonResponse);

        UA_LDEBUG(@"Setting Last-Modified time to '%@' for user %@'s message list.", lastModified, self.user.username);
        [self.dataStore setValue:lastModified
                          forKey:[NSString stringWithFormat:UALastMessageListModifiedTime, self.user.username]];

        successBlock(httpResponse.statusCode, messages);
    }];
}

- (void)performBatchDeleteForMessages:(NSArray *)messages
                            onSuccess:(UAInboxClientSuccessBlock)successBlock
                            onFailure:(UAInboxClientFailureBlock)failureBlock {

    UARequest *batchDeleteRequest = [self requestToPerformBatchDeleteForMessages:messages];

    [self.session dataTaskWithRequest:batchDeleteRequest retryWhere:^BOOL(NSData * _Nullable data, NSURLResponse * _Nullable response) {
        return NO;
    } completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *httpResponse = nil;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            httpResponse = (NSHTTPURLResponse *) response;
        }

        // Failure
        if (httpResponse.statusCode != 200) {

            [UAUtils logFailedRequest:batchDeleteRequest withMessage:@"Batch delete failed" withError:error withResponse:httpResponse];

            failureBlock();

            return;
        }

        // Success
        successBlock();

    }];
}

- (void)performBatchMarkAsReadForMessages:(NSArray *)messages
                                onSuccess:(UAInboxClientSuccessBlock)successBlock
                                onFailure:(UAInboxClientFailureBlock)failureBlock {

    UARequest *batchMarkAsReadRequest = [self requestToPerformBatchMarkReadForMessages:messages];

    [self.session dataTaskWithRequest:batchMarkAsReadRequest retryWhere:^BOOL(NSData * _Nullable data, NSURLResponse * _Nullable response) {
        return NO;
    } completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *httpResponse = nil;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            httpResponse = (NSHTTPURLResponse *) response;
        }

        // Failure
        if (httpResponse.statusCode != 200) {
            [UAUtils logFailedRequest:batchMarkAsReadRequest withMessage:@"Batch delete failed" withError:error withResponse:httpResponse];

            failureBlock();

            return;
        }

        // Success
        successBlock();
    }];
}

- (void)clearLastModifiedTime {
    if (self.user.username) {
        [self.dataStore removeObjectForKey:[NSString stringWithFormat:UALastMessageListModifiedTime, self.user.username]];
    }
}

@end
