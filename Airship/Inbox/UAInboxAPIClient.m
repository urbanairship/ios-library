
#import "UAInboxAPIClient.h"
#import "UAInbox.h"
#import "UAInboxMessage.h"
#import "UAHTTPRequestEngine.h"
#import "UAGlobal.h"
#import "UAirship.h"
#import "UAConfig.h"
#import "UAUser.h"
#import "UAUtils.h"
#import "NSJSONSerialization+UAAdditions.h"

@interface UAInboxAPIClient()

@property (nonatomic, strong) UAHTTPRequestEngine *requestEngine;

@end

@implementation UAInboxAPIClient

NSString *const UALastMessageListModifiedTime = @"UALastMessageListModifiedTime.%@";


- (instancetype)init {
    self = [super init];
    if (self) {
        self.requestEngine = [[UAHTTPRequestEngine alloc] init];
    }

    return self;
}


- (UAHTTPRequest *)requestToRetrieveMessageListForUser:(NSString *)userName {
    NSString *urlString = [NSString stringWithFormat: @"%@%@%@%@",
                           [UAirship shared].config.deviceAPIURL, @"/api/user/", userName,@"/messages/"];
    NSURL *requestUrl = [NSURL URLWithString: urlString];

    UAHTTPRequest *request = [UAUtils UAHTTPUserRequestWithURL:requestUrl method:@"GET"];

    NSString *lastModified = [[NSUserDefaults standardUserDefaults] stringForKey:[NSString stringWithFormat:UALastMessageListModifiedTime, userName]];
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
                           [UAirship shared].config.deviceAPIURL,
                           @"/api/user/",
                           [UAUser defaultUser].username,
                           @"/messages/delete/"];
    requestUrl = [NSURL URLWithString:urlString];

    data = @{@"delete" : updateMessageURLs};

    NSString* body = [NSJSONSerialization stringWithObject:data];

    UAHTTPRequest *request = [UAUtils UAHTTPUserRequestWithURL:requestUrl
                                                        method:@"POST"];


    [request addRequestHeader:@"Content-Type" value:@"application/json"];
    [request appendBodyData:[body dataUsingEncoding:NSUTF8StringEncoding]];

    UA_LTRACE(@"Request to perform batch delete: %@  body: %@", requestUrl, body);
    return request;
}

- (UAHTTPRequest *)requestToPerformBatchMarkReadForMessages:(NSArray *)messages {
    NSURL *requestUrl;
    NSDictionary *data;
    NSArray *updateMessageURLs = [messages valueForKeyPath:@"messageURL.absoluteString"];

    NSString *urlString = [NSString stringWithFormat:@"%@%@%@%@",
                           [UAirship shared].config.deviceAPIURL,
                           @"/api/user/",
                           [UAUser defaultUser].username,
                           @"/messages/unread/"];
    requestUrl = [NSURL URLWithString:urlString];

    data = @{@"mark_as_read" : updateMessageURLs};

    NSString* body = [NSJSONSerialization stringWithObject:data];

    UAHTTPRequest *request = [UAUtils UAHTTPUserRequestWithURL:requestUrl
                                                        method:@"POST"];


    [request addRequestHeader:@"Content-Type" value:@"application/json"];
    [request appendBodyData:[body dataUsingEncoding:NSUTF8StringEncoding]];

    UA_LTRACE(@"Request to perfom batch mark messages as read: %@ body: %@", requestUrl, body);
    return request;
}


- (void)retrieveMessageListOnSuccess:(UAInboxClientMessageRetrievalSuccessBlock)successBlock
                           onFailure:(UAInboxClientFailureBlock)failureBlock {

    NSString *userName = [UAUser defaultUser].username;
    UAHTTPRequest *retrieveRequest = [self requestToRetrieveMessageListForUser:userName];
    
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

              UA_LDEBUG(@"Setting Last-Modified time to '%@' for user %@'s message list.", lastModified, userName);
              [[NSUserDefaults standardUserDefaults] setValue:lastModified
                                                       forKey:[NSString stringWithFormat:UALastMessageListModifiedTime, userName]];

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

@end
