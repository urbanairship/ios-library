
#import "UAInboxAPIClient.h"
#import "UAInbox.h"
#import "UAInboxMessage.h"
#import "UAHTTPRequestEngine.h"
#import "UAGlobal.h"
#import "UAirship.h"
#import "UAConfig.h"
#import "UAUser.h"
#import "UAUtils.h"
#import "UA_SBJSON.h"

@interface UAInboxAPIClient()

@property(nonatomic, retain) UAHTTPRequestEngine *requestEngine;

@end

@implementation UAInboxAPIClient

- (id)init {
    if (self = [super init]) {
        self.requestEngine = [[[UAHTTPRequestEngine alloc] init] autorelease];
    }

    return self;
}

- (void)dealloc {
    self.requestEngine = nil;
    [super dealloc];
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
    UA_LDEBUG(@"%@", updateMessageURLs);

    NSString *urlString = [NSString stringWithFormat:@"%@%@%@%@",
                           [UAirship shared].config.deviceAPIURL,
                           @"/api/user/",
                           [UAUser defaultUser].username,
                           @"/messages/delete/"];
    requestUrl = [NSURL URLWithString:urlString];

    data = @{@"delete" : updateMessageURLs};

    UA_SBJsonWriter *writer = [[[UA_SBJsonWriter alloc] init] autorelease];
    NSString* body = [writer stringWithObject:data];

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

    UA_SBJsonWriter *writer = [[[UA_SBJsonWriter alloc] init] autorelease];
    NSString* body = [writer stringWithObject:data];

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
        successBlock();
     } onFailure:^(UAHTTPRequest *request, NSUInteger lastDelay){
        failureBlock(request);
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
          UA_SBJsonParser *parser = [[[UA_SBJsonParser alloc] init] autorelease];
          NSDictionary *jsonResponse = [parser objectWithString:request.responseString];
          UA_LTRACE(@"Retrieved message list respose: %@", request.responseString);

          // Convert dictionary to objects for convenience
          NSMutableArray *newMessages = [NSMutableArray array];
          for (NSDictionary *message in [jsonResponse objectForKey:@"messages"]) {
              UAInboxMessage *tmp = [[[UAInboxMessage alloc] initWithDict:message inbox:[UAInbox shared].messageList] autorelease];
              [newMessages addObject:tmp];
          }

          if (newMessages.count > 0) {
              NSSortDescriptor* dateDescriptor = [[[NSSortDescriptor alloc] initWithKey:@"messageSent"
                                                                              ascending:NO] autorelease];

              //TODO: this flow seems terribly backwards
              NSArray *sortDescriptors = [NSArray arrayWithObject:dateDescriptor];
              [newMessages sortUsingDescriptors:sortDescriptors];
          }

          NSUInteger unread = [[jsonResponse objectForKey: @"badge"] intValue];

          successBlock(newMessages, unread);
      } onFailure:^(UAHTTPRequest *request, NSUInteger lastDelay){
          failureBlock(request);
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
         successBlock();
     } onFailure:^(UAHTTPRequest *request, NSUInteger lastDelay){
         failureBlock(request);
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
         successBlock();
     } onFailure:^(UAHTTPRequest *request, NSUInteger lastDelay){
         failureBlock(request);
     }];
}

@end
