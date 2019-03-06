/* Copyright Urban Airship and Contributors */

#import "UAInboxMessageList+Internal.h"

#import "UAirship.h"
#import "UAConfig.h"
#import "UADisposable.h"
#import "UAInboxAPIClient+Internal.h"
#import "UAInboxMessage+Internal.h"
#import "UAInboxStore+Internal.h"
#import "UAUtils+Internal.h"
#import "UAUser.h"
#import "UAURLProtocol.h"
#import "UADate+Internal.h"

NSString * const UAInboxMessageListWillUpdateNotification = @"com.urbanairship.notification.message_list_will_update";
NSString * const UAInboxMessageListUpdatedNotification = @"com.urbanairship.notification.message_list_updated";

typedef void (^UAInboxMessageFetchCompletionHandler)(NSArray *);

@interface UAInboxMessageList()
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, strong) UADispatcher *dispatcher;
@property (nonatomic, strong) UADate *date;

@end

@implementation UAInboxMessageList

@synthesize messages = _messages;

#pragma mark Create Inbox

- (instancetype)initWithUser:(UAUser *)user
                      client:(UAInboxAPIClient *)client
                      config:(UAConfig *)config
                  inboxStore:(UAInboxStore *)inboxStore
          notificationCenter:(NSNotificationCenter *)notificationCenter
                  dispatcher:(UADispatcher *)dispatcher
                  date:(UADate *)date {

    self = [super init];

    if (self) {
        self.inboxStore = inboxStore;
        self.user = user;
        self.client = client;
        self.batchOperationCount = 0;
        self.retrieveOperationCount = 0;
        self.unreadCount = -1;
        self.messages = @[];
        self.notificationCenter = notificationCenter;
        self.dispatcher = dispatcher;
        self.date = date;
    }

    return self;
}

+ (instancetype)messageListWithUser:(UAUser *)user client:(UAInboxAPIClient *)client config:(UAConfig *)config {
    UAInboxStore *inboxStore = [UAInboxStore storeWithName:[NSString stringWithFormat:kUACoreDataStoreName, config.appKey]];

    return [UAInboxMessageList messageListWithUser:user
                                             client:client
                                             config:config
                                         inboxStore:inboxStore
                                 notificationCenter:[NSNotificationCenter defaultCenter]
                                         dispatcher:[UADispatcher mainDispatcher]
                                               date:[[UADate alloc] init]];
}

+ (instancetype)messageListWithUser:(UAUser *)user
                             client:(UAInboxAPIClient *)client
                             config:(UAConfig *)config
                         inboxStore:(UAInboxStore *)inboxStore
                 notificationCenter:(NSNotificationCenter *)notificationCenter
                         dispatcher:(UADispatcher *)dispatcher
                               date:(UADate *)date {

    
    return [[UAInboxMessageList alloc] initWithUser:user
                                             client:client
                                             config:config
                                         inboxStore:inboxStore
                                 notificationCenter:notificationCenter
                                         dispatcher:dispatcher
                                               date:date];
}

#pragma mark Accessors

- (void)setMessages:(NSArray *)messages {
    _messages = [messages copy];

    NSMutableDictionary *messageIDMap = [NSMutableDictionary dictionary];
    NSMutableDictionary *messageURLMap = [NSMutableDictionary dictionary];

    for (UAInboxMessage *message in _messages) {
        if (message.messageBodyURL.absoluteString) {
            [messageURLMap setObject:message forKey:message.messageBodyURL.absoluteString];
        }
        if (message.messageID) {
            [messageIDMap setObject:message forKey:message.messageID];
        }
    }

    self.messageIDMap = [messageIDMap copy];
    self.messageURLMap = [messageURLMap copy];
}

- (NSArray *)messages {
    return _messages;
}

- (NSArray<UAInboxMessage *> *)messagesFilteredUsingPredicate:(NSPredicate *)predicate {
    @synchronized(self) {
        return [_messages filteredArrayUsingPredicate:predicate];
    }
}

#pragma mark NSNotificationCenter helper methods

- (void)sendMessageListWillUpdateNotification {
    [self.notificationCenter postNotificationName:UAInboxMessageListWillUpdateNotification object:nil];
}

- (void)sendMessageListUpdatedNotification {
    [self.notificationCenter postNotificationName:UAInboxMessageListUpdatedNotification object:nil];
}

#pragma mark Update/Delete/Mark Messages

- (UADisposable *)retrieveMessageListWithSuccessBlock:(UAInboxMessageListCallbackBlock)successBlock
                                     withFailureBlock:(UAInboxMessageListCallbackBlock)failureBlock {


    UA_LDEBUG("Retrieving message list.");

    UA_WEAKIFY(self)
    [self.dispatcher dispatchAsyncIfNecessary:^{
        UA_STRONGIFY(self)
        self.retrieveOperationCount++;
        [self sendMessageListWillUpdateNotification];
    }];

    __block UAInboxMessageListCallbackBlock retrieveMessageListSuccessBlock = successBlock;
    __block UAInboxMessageListCallbackBlock retrieveMessageListFailureBlock = failureBlock;

    UADisposable *disposable = [UADisposable disposableWithBlock:^{
        retrieveMessageListSuccessBlock = nil;
        retrieveMessageListFailureBlock = nil;
    }];

    void (^completionBlock)(BOOL) = ^(BOOL success){
        UA_STRONGIFY(self)

        // Always refresh the listing even if it's a failure
        [self refreshInboxWithCompletionHandler:^ {
            if (self.retrieveOperationCount > 0) {
                self.retrieveOperationCount--;
            }
            if (success) {
                if (retrieveMessageListSuccessBlock) {
                    retrieveMessageListSuccessBlock();
                }
            } else {
                if (retrieveMessageListFailureBlock) {
                    retrieveMessageListFailureBlock();
                }
            }
            [self sendMessageListUpdatedNotification];
        }];
    };

    // Fetch
    [self.client retrieveMessageListOnSuccess:^(NSUInteger status, NSArray *messages) {
        UA_STRONGIFY(self)

        // Sync client state
        [self syncLocalMessageState];

        UA_LDEBUG(@"Retrieve message list succeeded with status: %lu", (unsigned long)status);

        if (status == 200) {
            [self.inboxStore syncMessagesWithResponse:messages completionHandler:^(BOOL success) {
                UA_STRONGIFY(self)
                if (!success) {
                    [self.client clearLastModifiedTime];
                    completionBlock(NO);
                } else {
                    completionBlock(YES);
                }
            }];
        } else {
            // 304
            completionBlock(YES);
        }
    } onFailure:^(){
        UA_LDEBUG(@"Retrieve message list failed");
        completionBlock(NO);
    }];

    return disposable;
}


- (UADisposable *)markMessagesRead:(NSArray *)messages completionHandler:(UAInboxMessageListCallbackBlock)completionHandler {
    if (!messages.count) {
        return nil;
    }

    NSArray *messageIDs = [messages valueForKeyPath:@"messageID"];

    UA_WEAKIFY(self)
    [self.dispatcher dispatchAsyncIfNecessary:^{
        UA_STRONGIFY(self)
        for (UAInboxMessage *message in messages) {
            message.unread = NO;
        }
        self.batchOperationCount++;
        [self sendMessageListWillUpdateNotification];
    }];

    __block UAInboxMessageListCallbackBlock inboxMessageListCompletionBlock = completionHandler;
    UADisposable *disposable = [UADisposable disposableWithBlock:^{
        inboxMessageListCompletionBlock = nil;
    }];

    [self.inboxStore fetchMessagesWithPredicate:[NSPredicate predicateWithFormat:@"messageID IN %@", messageIDs]
                              completionHandler:^(NSArray<UAInboxMessageData *> *data) {
                                  UA_STRONGIFY(self)
                                  UA_LDEBUG(@"Marking messages as read: %@.", messageIDs);
                                  for (UAInboxMessageData *messageData in data) {
                                      messageData.unreadClient = NO;
                                  }

                                  // Refresh the messages
                                  [self refreshInboxWithCompletionHandler:^{
                                      UA_STRONGIFY(self)
                                      if (self.batchOperationCount > 0) {
                                          self.batchOperationCount--;
                                      }

                                      if (inboxMessageListCompletionBlock) {
                                          inboxMessageListCompletionBlock();
                                      }

                                      [self sendMessageListUpdatedNotification];
                                  }];

                                  [self syncLocalMessageState];
                              }];

    return disposable;
}

- (UADisposable *)markMessagesDeleted:(NSArray *)messages completionHandler:(UAInboxMessageListCallbackBlock)completionHandler{
    if (!messages.count) {
        return nil;
    }

    NSArray *messageIDs = [messages valueForKeyPath:@"messageID"];


    UA_WEAKIFY(self)
    [self.dispatcher dispatchAsyncIfNecessary:^{
        UA_STRONGIFY(self)
        for (UAInboxMessage *message in messages) {
            message.unread = NO;
        }
        self.batchOperationCount++;
        [self sendMessageListWillUpdateNotification];
    }];

    __block UAInboxMessageListCallbackBlock inboxMessageListCompletionBlock = completionHandler;
    UADisposable *disposable = [UADisposable disposableWithBlock:^{
        inboxMessageListCompletionBlock = nil;
    }];

    [self.inboxStore fetchMessagesWithPredicate:[NSPredicate predicateWithFormat:@"messageID IN %@", messageIDs]
                              completionHandler:^(NSArray<UAInboxMessageData *> *data) {

                                  UA_STRONGIFY(self)

                                  UA_LTRACE(@"Marking messages as deleted %@.", messageIDs);
                                  for (UAInboxMessageData *messageData in data) {
                                      messageData.deletedClient = YES;
                                  }

                                  // Refresh the messages
                                  [self refreshInboxWithCompletionHandler:^{
                                      if (self.batchOperationCount > 0) {
                                          self.batchOperationCount--;
                                      }

                                      if (inboxMessageListCompletionBlock) {
                                          inboxMessageListCompletionBlock();
                                      }

                                      [self sendMessageListUpdatedNotification];
                                  }];

                                  [self syncLocalMessageState];
                              }];


    return disposable;
}

- (void)loadSavedMessages {
    // First load
    [self sendMessageListWillUpdateNotification];
    [self refreshInboxWithCompletionHandler:^ {
        [self sendMessageListUpdatedNotification];
    }];
}

#pragma mark -
#pragma mark Internal/Helper Methods


/**
 * Refreshes the publicly exposed inbox messages on the private context.
 * The completion handler is executed on the main context.
 *
 * @param completionHandler Optional completion handler.
 */
- (void)refreshInboxWithCompletionHandler:(void (^)(void))completionHandler {
    NSString *predicateFormat = @"(messageExpiration == nil || messageExpiration >= %@) && (deletedClient == NO || deletedClient == nil)";
    NSPredicate *predicate = [NSPredicate predicateWithFormat:predicateFormat, [self.date now]];

    UA_WEAKIFY(self)
    [self.inboxStore fetchMessagesWithPredicate:predicate
                              completionHandler:^(NSArray<UAInboxMessageData *> *data) {
                                  UA_STRONGIFY(self)
                                  NSInteger unreadCount = 0;
                                  NSMutableArray *messages = [NSMutableArray arrayWithCapacity:data.count];

                                  for (UAInboxMessageData *messageData in data) {
                                      UAInboxMessage *message = [self messageFromMessageData:messageData];
                                      if (message.unread) {
                                          unreadCount ++;
                                      }

                                      [messages addObject:message];
                                  }

                                  [self.dispatcher dispatchAsync:^{
                                      UA_LDEBUG(@"Inbox messages updated.");
                                      UA_LTRACE(@"Loaded saved messages: %@.", messages);
                                      self.unreadCount = unreadCount;
                                      self.messages = messages;

                                      if (completionHandler) {
                                          completionHandler();
                                      }
                                  }];
                              }];
}

/**
 * Synchronizes local read messages state with the server, on the private context.
 */
- (void)syncReadMessageState {
    UA_WEAKIFY(self)
    [self.inboxStore fetchMessagesWithPredicate:[NSPredicate predicateWithFormat:@"unreadClient == NO && unread == YES"]
                              completionHandler:^(NSArray<UAInboxMessageData *> *data) {
                                  UA_STRONGIFY(self)

                                  if (!data.count) {
                                      // Nothing to do
                                      return;
                                  }

                                  NSArray *messageURLs = [data valueForKeyPath:@"messageURL"];
                                  NSArray *messageIDs = [data valueForKeyPath:@"messageID"];

                                  UA_LTRACE(@"Synchronizing locally read messages %@ on server.", messageIDs);

                                  [self.client performBatchMarkAsReadForMessageURLs:messageURLs onSuccess:^{

                                      // Mark the messages as read
                                      [self.inboxStore fetchMessagesWithPredicate:[NSPredicate predicateWithFormat:@"messageID IN %@", messageIDs]
                                                                completionHandler:^(NSArray<UAInboxMessageData *> *data) {
                                                                    for (UAInboxMessageData *messageData in data) {
                                                                        messageData.unread = NO;
                                                                    }

                                                                    UA_LTRACE(@"Successfully synchronized locally read messages on server.");
                                                                }];
                                  } onFailure:^() {
                                      UA_LTRACE(@"Failed to synchronize locally read messages on server.");
                                  }];

                              }];
}

/**
 * Synchronizes local deleted message state with the server, on the private context.
 */
- (void)syncDeletedMessageState {

    UA_WEAKIFY(self)
    [self.inboxStore fetchMessagesWithPredicate:[NSPredicate predicateWithFormat:@"deletedClient == YES"]
                              completionHandler:^(NSArray<UAInboxMessageData *> *data) {
                                  UA_STRONGIFY(self)

                                  if (!data.count) {
                                      // Nothing to do
                                      return;
                                  }


                                  NSArray *messageURLs = [data valueForKeyPath:@"messageURL"];
                                  NSArray *messageIDs = [data valueForKeyPath:@"messageID"];

                                  UA_LTRACE(@"Synchronizing locally deleted messages %@ on server.", messageIDs);

                                  [self.client performBatchDeleteForMessageURLs:messageURLs onSuccess:^{
                                      UA_LTRACE(@"Successfully synchronized locally deleted messages on server.");
                                  } onFailure:^() {
                                      UA_LTRACE(@"Failed to synchronize locally deleted messages on server.");
                                  }];
                              }];
}

/**
 * Synchronizes any local read or deleted message state with the server, on the private context.
 */
- (void)syncLocalMessageState {
    [self syncReadMessageState];
    [self syncDeletedMessageState];
}

- (NSUInteger)messageCount {
    return [self.messages count];
}

- (UAInboxMessage *)messageForBodyURL:(NSURL *)url {
    return [self.messageURLMap objectForKey:url.absoluteString];
}

- (UAInboxMessage *)messageForID:(NSString *)messageID {
    return [self.messageIDMap objectForKey:messageID];
}

- (BOOL)isRetrieving {
    return self.retrieveOperationCount > 0;
}

- (BOOL)isBatchUpdating {
    return self.batchOperationCount > 0;
}

- (id)debugQuickLookObject {
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:@""];

    NSUInteger index = 0;
    NSUInteger characterIndex = 0;
    for (UAInboxMessage *message in self.messages) {
        NSString *line = index < self.messages.count-1 ? [NSString stringWithFormat:@"%@\n", message.title] : message.title;
        [attributedString.mutableString appendString:line];
        // Display unread messages in bold text
        NSString *fontName = message.unread ? @"Helvetica Bold" : @"Helvetica";
        [attributedString addAttribute:NSFontAttributeName value:[UIFont fontWithName:fontName size:15]
                                 range:NSMakeRange(characterIndex, line.length)];
        index++;
        characterIndex += line.length;
    }

    return attributedString;
}

- (UAInboxMessage *)messageFromMessageData:(UAInboxMessageData *)data {
    return [UAInboxMessage messageWithBuilderBlock:^(UAInboxMessageBuilder *builder) {
        builder.messageURL = data.messageURL;
        builder.messageID = data.messageID;
        builder.messageSent = data.messageSent;
        builder.messageBodyURL = data.messageBodyURL;
        builder.messageExpiration = data.messageExpiration;
        builder.unread = data.unreadClient & data.unread;
        builder.rawMessageObject = data.rawMessageObject;
        builder.extra = data.extra;
        builder.title = data.title;
        builder.contentType = data.contentType;
        builder.messageList = self;
    }];
}

@end

