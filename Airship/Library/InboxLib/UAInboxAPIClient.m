
#import "UAInboxAPIClient.h"
#import "UAInbox.h"
#import "UAInboxMessage.h"
#import "UAHTTPRequestEngine.h"
#import "UAGlobal.h"
#import "UAirship.h"
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
    UA_LDEBUG(@"MARK AS READ %@", urlString);

    UAHTTPRequest *request = [UAUtils UAHTTPUserRequestWithURL:url method:@"POST"];

    return request;
}

- (UAHTTPRequest *)requestToRetrieveMessageList {
    NSString *urlString = [NSString stringWithFormat: @"%@%@%@%@",
                           [[UAirship shared] server], @"/api/user/", [UAUser defaultUser].username ,@"/messages/"];


    UALOG(@"%@",urlString);
    NSURL *requestUrl = [NSURL URLWithString: urlString];

    UAHTTPRequest *request = [UAUtils UAHTTPUserRequestWithURL:requestUrl method:@"GET"];

    return request;
}

- (UAHTTPRequest *)requestToPerformBatchDeleteForMessages:(NSArray *)messages {
    NSURL *requestUrl;
    NSDictionary *data;
    NSArray *updateMessageURLs = [messages valueForKeyPath:@"messageURL.absoluteString"];
    UA_LDEBUG(@"%@", updateMessageURLs);

    NSString *urlString = [NSString stringWithFormat:@"%@%@%@%@",
                           [UAirship shared].server,
                           @"/api/user/",
                           [UAUser defaultUser].username,
                           @"/messages/delete/"];
    requestUrl = [NSURL URLWithString:urlString];
    UALOG(@"batch delete url: %@", requestUrl);

    data = [NSDictionary dictionaryWithObject:updateMessageURLs forKey:@"delete"];

    UA_SBJsonWriter *writer = [UA_SBJsonWriter new];
    NSString* body = [writer stringWithObject:data];
    [writer release];

    UAHTTPRequest *request = [UAUtils UAHTTPUserRequestWithURL:requestUrl
                                                        method:@"POST"];


    [request addRequestHeader:@"Content-Type" value:@"application/json"];
    [request appendBodyData:[body dataUsingEncoding:NSUTF8StringEncoding]];

    return request;
}

- (UAHTTPRequest *)requestToPerformBatchReadForMessages:(NSArray *)messages {
    NSURL *requestUrl;
    NSDictionary *data;
    NSArray *updateMessageURLs = [messages valueForKeyPath:@"messageURL.absoluteString"];
    UA_LDEBUG(@"%@", updateMessageURLs);

    NSString *urlString = [NSString stringWithFormat:@"%@%@%@%@",
                           [UAirship shared].server,
                           @"/api/user/",
                           [UAUser defaultUser].username,
                           @"/messages/unread/"];
    requestUrl = [NSURL URLWithString:urlString];
    UALOG(@"batch mark as read url: %@", requestUrl);

    data = [NSDictionary dictionaryWithObject:updateMessageURLs forKey:@"mark_as_read"];

    UA_SBJsonWriter *writer = [UA_SBJsonWriter new];
    NSString* body = [writer stringWithObject:data];
    [writer release];

    UAHTTPRequest *request = [UAUtils UAHTTPUserRequestWithURL:requestUrl
                                                        method:@"POST"];


    [request addRequestHeader:@"Content-Type" value:@"application/json"];
    [request appendBodyData:[body dataUsingEncoding:NSUTF8StringEncoding]];

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
     } onSuccess:^(UAHTTPRequest *request, NSInteger lastDelay){
        successBlock();
     } onFailure:^(UAHTTPRequest *request, NSInteger lastDelay){
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
      } onSuccess:^(UAHTTPRequest *request, NSInteger lastDelay){
          UA_SBJsonParser *parser = [[[UA_SBJsonParser alloc] init] autorelease];
          NSDictionary *jsonResponse = [parser objectWithString: [request responseString]];
          UALOG(@"Retrieved Messages: %@", [request responseString]);

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

          NSInteger unread = [[jsonResponse objectForKey: @"badge"] intValue];

          successBlock(newMessages, unread);
      } onFailure:^(UAHTTPRequest *request, NSInteger lastDelay){
          failureBlock(request);
      }];
}

- (void)performBatchUpdateCommand:(UABatchUpdateCommand)command
                      forMessages:(NSArray *)messages
                         onSuccess:(UAInboxClientSuccessBlock)successBlock
                        onFailure:(UAInboxClientFailureBlock)failureBlock  {

    UAHTTPRequest *batchUpdateRequest;

    if (command == UABatchDeleteMessages) {
        batchUpdateRequest = [self requestToPerformBatchDeleteForMessages:messages];
    } else if (command == UABatchReadMessages) {
        batchUpdateRequest = [self requestToPerformBatchReadForMessages:messages];
    } else {
        UA_LERR(@"command=%d is invalid.", command);
        return;
    }

    [self.requestEngine
     runRequest:batchUpdateRequest
     succeedWhere:^(UAHTTPRequest *request){
         return (BOOL)(request.response.statusCode == 200);
     } retryWhere:^(UAHTTPRequest *request){
         return NO;
     } onSuccess:^(UAHTTPRequest *request, NSInteger lastDelay){
         successBlock();
     } onFailure:^(UAHTTPRequest *request, NSInteger lastDelay){
         failureBlock(request);
     }];
}

@end
