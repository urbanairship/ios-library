
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
#import "UAInboxDBManager+Internal.h"

@interface UAInboxAPIClient()

@property(nonatomic, strong) UAHTTPRequestEngine *requestEngine;

@end

@implementation UAInboxAPIClient

- (id)init {
    self = [super init];
    if (self) {
        self.requestEngine = [[UAHTTPRequestEngine alloc] init];
    }

    return self;
}


- (UAHTTPRequest *)requestToMarkMessageRead:(UAInboxMessage *)message {
    NSString *urlString = [NSString stringWithFormat: @"%@%@", message.messageURL, @"read/"];
    NSURL *url = [NSURL URLWithString: urlString];
    
    UAHTTPRequest *request = [UAUtils UAHTTPUserRequestWithURL:url method:@"POST"];
    
    UA_LTRACE(@"Request to mark message as read: %@", urlString);
    return request;
}

- (UAHTTPRequest *)requestToRetrieveMessageList {
    NSString *urlString = [NSString stringWithFormat: @"%@%@%@%@",
                           [UAirship shared].config.deviceAPIURL, @"/api/user/", [UAUser defaultUser].username ,@"/messages/"];
    NSURL *requestUrl = [NSURL URLWithString: urlString];

    UAHTTPRequest *request = [UAUtils UAHTTPUserRequestWithURL:requestUrl method:@"GET"];
    
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
    UA_LDEBUG(@"%@", updateMessageURLs);

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

- (void)markMessageRead:(UAInboxMessage *)message
              onSuccess:(UAInboxClientSuccessBlock)successBlock
                  onFailure:(UAInboxClientFailureBlock)failureBlock {
    
    UAHTTPRequest *readRequest = [self requestToMarkMessageRead:message];

    [self.requestEngine
     runRequest:readRequest
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
         if (failureBlock) {
            failureBlock(request);
         } else {
             UA_LERR(@"missing failureBlock");
         }
     }];
}

- (void)retrieveMessageListOnSuccess:(UAInboxClientRetrievalSuccessBlock)successBlock
                           onFailure:(UAInboxClientFailureBlock)failureBlock {

    UAHTTPRequest *retrieveRequest = [self requestToRetrieveMessageList];
    
    [self.requestEngine
      runRequest:retrieveRequest
      succeedWhere:^(UAHTTPRequest *request){
          return (BOOL)(request.response.statusCode == 200);
      } retryWhere:^(UAHTTPRequest *request){
          return NO;
      } onSuccess:^(UAHTTPRequest *request, NSUInteger lastDelay){
          UAInboxDBManager *inboxDBManager = [UAInboxDBManager shared];
          NSString *responseString = request.responseString;
          NSDictionary *jsonResponse = [NSJSONSerialization objectWithString:responseString];
          UA_LTRACE(@"Retrieved message list response: %@", responseString);

          NSMutableSet *responseMessageIDs = [NSMutableSet set];

          // Convert dictionary to objects for convenience          
          for (NSDictionary *message in [jsonResponse objectForKey:@"messages"]) {
              if (![inboxDBManager updateMessageWithDictionary:message]) {
                  UAInboxMessage *tmp = [inboxDBManager addMessageFromDictionary:message];
                  tmp.inbox = [UAInbox shared].messageList;
              }

              NSString *messageID = [message valueForKey:@"message_id"];
              if (messageID) {
                  [responseMessageIDs addObject:messageID];
              }
          }

          NSInteger unread = [[jsonResponse objectForKey: @"badge"] integerValue];
          if (unread < 0) {
              unread = 0;
          }

          // Delete server side deleted messages
          NSMutableSet *messagesToDelete = [[inboxDBManager messageIDs] mutableCopy];
          [messagesToDelete minusSet:responseMessageIDs];
          [inboxDBManager deleteMessagesWithIDs:messagesToDelete];

          // Delete any expired messages
          [[UAInboxDBManager shared] deleteExpiredMessages];

          if (successBlock) {
             successBlock([[inboxDBManager getMessages] mutableCopy], (NSUInteger) unread);
          } else {
              UA_LERR(@"missing successBlock");
          }
      } onFailure:^(UAHTTPRequest *request, NSUInteger lastDelay){
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
         if (failureBlock) {
             failureBlock(request);
         } else {
             UA_LERR(@"missing failureBlock");
         }
     }];
}

@end
