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

#import "UAInboxAPIClient+Internal.h"
#import "UAInboxMessage.h"
#import "UAHTTPRequestEngine+Internal.h"
#import "UAConfig.h"
#import "UAUser.h"
#import "UAUtils.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAirship.h"
#import "UAPush.h"

@interface UAInboxAPIClient()

@property (nonatomic, strong) UAHTTPRequestEngine *requestEngine;
@property (nonatomic, strong) UAConfig *config;
@property (nonatomic, strong) UAUser *user;
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;

@end

@implementation UAInboxAPIClient

NSString *const UALastMessageListModifiedTime = @"UALastMessageListModifiedTime.%@";

- (instancetype)initWithUser:(UAUser *)user config:(UAConfig *)config dataStore:(UAPreferenceDataStore *)dataStore {
    self = [super init];
    if (self) {
        self.user = user;
        self.config = config;
        self.dataStore = dataStore;
        self.requestEngine = [[UAHTTPRequestEngine alloc] init];
    }

    return self;
}

+ (instancetype)clientWithUser:(UAUser *)user config:(UAConfig *)config dataStore:(UAPreferenceDataStore *)dataStore {
    return [[UAInboxAPIClient alloc] initWithUser:user config:config dataStore:dataStore];
}

- (UAHTTPRequest *)requestToRetrieveMessageList{
    NSString *urlString = [NSString stringWithFormat: @"%@%@%@%@",
                           self.config.deviceAPIURL, @"/api/user/", self.user.username,@"/messages/"];

    NSURL *requestUrl = [NSURL URLWithString: urlString];

    UAHTTPRequest *request = [UAHTTPRequest requestWithURL:requestUrl];
    request.HTTPMethod = @"GET";
    request.username = self.user.username;
    request.password = self.user.password;

    [request addRequestHeader:kUAChannelIDHeader value:[UAirship push].channelID];

    NSString *lastModified = [self.dataStore stringForKey:[NSString stringWithFormat:UALastMessageListModifiedTime, self.user.username]];
    if (lastModified) {
        [request addRequestHeader:@"If-Modified-Since" value:lastModified];
    }

    UA_LTRACE(@"Request to retrieve message list: %@", urlString);
    return request;
}

- (UAHTTPRequest *)requestToPerformBatchDeleteForMessages:(NSArray *)messages {
    NSURL *requestUrl;
    NSDictionary *data;
    NSArray *updateMessageURLs = [messages valueForKeyPath:@"messageURL.absoluteString"];

    NSString *urlString = [NSString stringWithFormat:@"%@%@%@%@",
                           self.config.deviceAPIURL,
                           @"/api/user/",
                           self.user.username,
                           @"/messages/delete/"];

    requestUrl = [NSURL URLWithString:urlString];

    data = @{@"delete" : updateMessageURLs};

    NSString* body = [NSJSONSerialization stringWithObject:data];

    UAHTTPRequest *request = [UAHTTPRequest requestWithURL:requestUrl];
    request.HTTPMethod = @"POST";
    request.username = self.user.username;
    request.password = self.user.password;

    [request addRequestHeader:@"Content-Type" value:@"application/json"];

    [request addRequestHeader:kUAChannelIDHeader value:[UAirship push].channelID];

    [request appendBodyData:[body dataUsingEncoding:NSUTF8StringEncoding]];

    UA_LTRACE(@"Request to perform batch delete: %@  body: %@", requestUrl, body);
    return request;
}

- (UAHTTPRequest *)requestToPerformBatchMarkReadForMessages:(NSArray *)messages {
    NSURL *requestUrl;
    NSDictionary *data;
    NSArray *updateMessageURLs = [messages valueForKeyPath:@"messageURL.absoluteString"];

    NSString *urlString = [NSString stringWithFormat:@"%@%@%@%@",
                           self.config.deviceAPIURL,
                           @"/api/user/",
                           self.user.username,
                           @"/messages/unread/"];

    requestUrl = [NSURL URLWithString:urlString];

    data = @{@"mark_as_read" : updateMessageURLs};

    NSString* body = [NSJSONSerialization stringWithObject:data];

    UAHTTPRequest *request = [UAHTTPRequest requestWithURL:requestUrl];
    request.HTTPMethod = @"POST";
    request.username = self.user.username;
    request.password = self.user.password;

    [request addRequestHeader:@"Content-Type" value:@"application/json"];
    [request appendBodyData:[body dataUsingEncoding:NSUTF8StringEncoding]];

    [request addRequestHeader:kUAChannelIDHeader value:[UAirship push].channelID];

    UA_LTRACE(@"Request to perfom batch mark messages as read: %@ body: %@", requestUrl, body);
    return request;
}


- (void)retrieveMessageListOnSuccess:(UAInboxClientMessageRetrievalSuccessBlock)successBlock
                           onFailure:(UAInboxClientFailureBlock)failureBlock {

    UAHTTPRequest *retrieveRequest = [self requestToRetrieveMessageList];

    [self.requestEngine
      runRequest:retrieveRequest
      succeedWhere:^(UAHTTPRequest *request){
          return (BOOL)(request.response.statusCode == 200 || request.response.statusCode == 304);
      } retryWhere:^(UAHTTPRequest *request){
          return NO;
      } onSuccess:^(UAHTTPRequest *request, NSUInteger lastDelay){
          NSArray *messages;
          NSInteger unread = 0;
          NSInteger statusCode = request.response.statusCode;

          if (statusCode == 200) {
              NSDictionary *headers = request.response.allHeaderFields;
              NSString *lastModified = [headers objectForKey:@"Last-Modified"];

              UA_LDEBUG(@"Setting Last-Modified time to '%@' for user %@'s message list.", lastModified, self.user.username);
              [self.dataStore setValue:lastModified
                                forKey:[NSString stringWithFormat:UALastMessageListModifiedTime, self.user.username]];

              NSString *responseString = request.responseString;
              UA_LTRACE(@"Retrieved message list response: %@", responseString);

              NSDictionary *jsonResponse = [NSJSONSerialization objectWithString:responseString];
              messages = [jsonResponse objectForKey:@"messages"];

              unread = [[jsonResponse objectForKey: @"badge"] integerValue];
              if (unread < 0) {
                  unread = 0;
              }
          }


          if (successBlock) {
             successBlock(statusCode, messages, unread);
          } else {
              UA_LERR(@"missing successBlock");
          }
      } onFailure:^(UAHTTPRequest *request, NSUInteger lastDelay){
          [UAUtils logFailedRequest:request withMessage:@"Retrieve messages failed"];

          if (failureBlock) {
              failureBlock(request);
          } else {
              UA_LERR(@"missing failureBlock");
          }
      }];
}

- (void)performBatchDeleteForMessages:(NSArray *)messages
                            onSuccess:(UAInboxClientSuccessBlock)successBlock
                            onFailure:(UAInboxClientFailureBlock)failureBlock {

    UAHTTPRequest *batchDeleteRequest = [self requestToPerformBatchDeleteForMessages:messages];

    [self.requestEngine
     runRequest:batchDeleteRequest
     succeedWhere:^(UAHTTPRequest *request){
         return (BOOL)(request.response.statusCode == 200);
     } retryWhere:^(UAHTTPRequest *request){
         return NO;
     } onSuccess:^(UAHTTPRequest *request, NSUInteger lastDelay){
         if (successBlock) {
             successBlock();
         } else {
             UA_LERR(@"missing successBlock");
         }
     } onFailure:^(UAHTTPRequest *request, NSUInteger lastDelay){
         [UAUtils logFailedRequest:request withMessage:@"Batch delete failed"];
         if (failureBlock) {
             failureBlock(request);
         } else {
             UA_LERR(@"missing failureBlock");
         }
     }];
}

- (void)performBatchMarkAsReadForMessages:(NSArray *)messages
                                onSuccess:(UAInboxClientSuccessBlock)successBlock
                                onFailure:(UAInboxClientFailureBlock)failureBlock {

    UAHTTPRequest *batchMarkAsReadRequest = [self requestToPerformBatchMarkReadForMessages:messages];

    [self.requestEngine
     runRequest:batchMarkAsReadRequest
     succeedWhere:^(UAHTTPRequest *request){
         return (BOOL)(request.response.statusCode == 200);
     } retryWhere:^(UAHTTPRequest *request){
         return NO;
     } onSuccess:^(UAHTTPRequest *request, NSUInteger lastDelay){
         if (successBlock) {
            successBlock();
         } else {
             UA_LERR(@"missing successBlock");
         }
     } onFailure:^(UAHTTPRequest *request, NSUInteger lastDelay){
         [UAUtils logFailedRequest:request withMessage:@"Batch mark read failed"];
         if (failureBlock) {
             failureBlock(request);
         } else {
             UA_LERR(@"missing failureBlock");
         }
     }];
}

- (void)cancelAllRequests {
    [self.requestEngine cancelAllRequests];
}

- (void)clearLastModifiedTime {
    if (self.user.username) {
        [self.dataStore removeObjectForKey:[NSString stringWithFormat:UALastMessageListModifiedTime, self.user.username]];
    }
}

@end
