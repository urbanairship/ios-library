/* Copyright 2017 Urban Airship and Contributors */

#import "UAInboxMessageList+Internal.h"

#import "UAirship.h"
#import "UAConfig.h"
#import "UADisposable.h"
#import "UAInbox.h"
#import "UAInboxAPIClient+Internal.h"
#import "UAInboxMessage+Internal.h"
#import "UAInboxDBManager+Internal.h"
#import "UAUtils.h"
#import "UAUser.h"
#import "UAURLProtocol.h"

NSString * const UAInboxMessageListWillUpdateNotification = @"com.urbanairship.notification.message_list_will_update";
NSString * const UAInboxMessageListUpdatedNotification = @"com.urbanairship.notification.message_list_updated";

typedef void (^UAInboxMessageFetchCompletionHandler)(NSArray *);

@implementation UAInboxMessageList

@synthesize messages = _messages;

#pragma mark Create Inbox

- (instancetype)initWithUser:(UAUser *)user client:(UAInboxAPIClient *)client config:(UAConfig *)config {
    self = [super init];

    if (self) {
        self.inboxDBManager = [[UAInboxDBManager alloc] initWithConfig:config];
        self.user = user;
        self.client = client;
        self.batchOperationCount = 0;
        self.retrieveOperationCount = 0;
        self.unreadCount = -1;
    }

    return self;
}

+ (instancetype)messageListWithUser:(UAUser *)user client:(UAInboxAPIClient *)client config:(UAConfig *)config{
    return [[UAInboxMessageList alloc] initWithUser:user client:client config:config];
}

#pragma mark Accessors

- (void)setMessages:(NSArray *)messages {
    _messages = messages;
    
    NSMutableDictionary *messageIDMap = [NSMutableDictionary dictionary];
    NSMutableDictionary *messageURLMap = [NSMutableDictionary dictionary];
    
    for (UAInboxMessage *message in messages) {
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
    [[NSNotificationCenter defaultCenter] postNotificationName:UAInboxMessageListWillUpdateNotification object:nil];
}

- (void)sendMessageListUpdatedNotification {
    [[NSNotificationCenter defaultCenter] postNotificationName:UAInboxMessageListUpdatedNotification object:nil];
}

#pragma mark Update/Delete/Mark Messages

- (UADisposable *)retrieveMessageListWithSuccessBlock:(UAInboxMessageListCallbackBlock)successBlock
                                     withFailureBlock:(UAInboxMessageListCallbackBlock)failureBlock {

    if (!self.user.isCreated) {
        return nil;
    }

    UA_LDEBUG("Retrieving message list.");

    self.retrieveOperationCount++;
    [self sendMessageListWillUpdateNotification];

    __block UAInboxMessageListCallbackBlock retrieveMessageListSuccessBlock = successBlock;
    __block UAInboxMessageListCallbackBlock retrieveMessageListFailureBlock = failureBlock;

    UADisposable *disposable = [UADisposable disposableWithBlock:^{
        retrieveMessageListSuccessBlock = nil;
        retrieveMessageListFailureBlock = nil;
    }];

    void (^completionBlock)(BOOL) = ^(BOOL success){
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
    };

    // Fetch new messages
    [self.client retrieveMessageListOnSuccess:^(NSUInteger status, NSArray *messages) {
        // Sync client state
        [self syncLocalMessageState];

        if (status == 200) {
            UA_LDEBUG(@"Refreshing message list.");

            // Synchronize local messages with the response on the private context
            [self syncMessagesWithResponse:messages completionHandler:^{
                // Push changes onto the main context
                [self refreshInboxWithCompletionHandler:^{
                    completionBlock(YES);
                }];
            }];
        } else {
            UA_LDEBUG(@"Retrieve message list succeeded with status: %lu", (unsigned long)status);
            completionBlock(YES);
        }

    } onFailure:^(){
        UA_LDEBUG(@"Retrieve message list failed");
        completionBlock(NO);
    }];

    return disposable;
}


- (UADisposable *)markMessagesRead:(NSArray *)messages completionHandler:(UAInboxMessageListCallbackBlock)completionHandler {
    // Gather the object IDs so we can perform the operation on the private context
    NSArray *objectIDs = [messages valueForKeyPath:@"data.objectID"];
    if (!objectIDs.count) {
        return nil;
    }

    self.batchOperationCount++;
    [self sendMessageListWillUpdateNotification];

    __block UAInboxMessageListCallbackBlock inboxMessageListCompletionBlock = completionHandler;
    UADisposable *disposable = [UADisposable disposableWithBlock:^{
        inboxMessageListCompletionBlock = nil;
    }];

    // Fetch the objects on the private context
    NSManagedObjectContext *context = self.inboxDBManager.privateContext;

    [self.inboxDBManager fetchMessagesWithPredicate:[NSPredicate predicateWithFormat:@"self IN %@", objectIDs]
                                            context:context
                                  completionHandler:^(NSArray *messages) {

                                      UA_LDEBUG(@"Marking messages as read %@.", messages);
                                      for (UAInboxMessage *message in messages) {
                                          if ([message isKindOfClass:[UAInboxMessage class]] && !message.data.isGone) {
                                              message.data.unreadClient = NO;
                                          }
                                      }

                                      [context save:nil];

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

- (UADisposable *)markMessagesDeleted:(NSArray *)messages completionHandler:(UAInboxMessageListCallbackBlock)completionHandler{
    // Gather the object IDs so we can perform the operation on the private context
    NSArray *objectIDs = [messages valueForKeyPath:@"data.objectID"];
    if (!objectIDs.count) {
        return nil;
    }

    self.batchOperationCount++;
    [self sendMessageListWillUpdateNotification];

    __block UAInboxMessageListCallbackBlock inboxMessageListCompletionBlock = completionHandler;
    UADisposable *disposable = [UADisposable disposableWithBlock:^{
        inboxMessageListCompletionBlock = nil;
    }];

    // Fetch the objects on the private context
    NSManagedObjectContext *context = self.inboxDBManager.privateContext;

    [self.inboxDBManager fetchMessagesWithPredicate:[NSPredicate predicateWithFormat:@"self IN %@", objectIDs]
                                            context:context
                                  completionHandler:^(NSArray *messages) {

                                      UA_LDEBUG(@"Marking messages as deleted %@.", messages);
                                      for (UAInboxMessage *message in messages) {
                                          if ([message isKindOfClass:[UAInboxMessage class]] && !message.data.isGone) {
                                              message.data.deletedClient = YES;
                                          }
                                      }

                                      [context save:nil];

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
 * Synchronizes local messages with response from a remote message retrieval, on the private context.
 *
 * @param messages The messages returned from a remote message retrieval.
 * @param completionHandler An optional completion handler run when the sync is complete.
 */
- (void)syncMessagesWithResponse:(NSArray *)messages completionHandler:(void(^)())completionHandler {

    NSManagedObjectContext *context = self.inboxDBManager.privateContext;

    [context performBlock:^{
        // Track the response messageIDs so we can remove any messages that are
        // no longer in the response.
        NSMutableSet *responseMessageIDs = [NSMutableSet set];

        for (NSDictionary *messagePayload in messages) {
            NSString *messageID = messagePayload[@"message_id"];

            if (!messageID) {
                UA_LDEBUG(@"Missing message ID: %@", messagePayload);
                continue;
            }

            if (![self.inboxDBManager updateMessageWithDictionary:messagePayload context:context]) {
                [self.inboxDBManager addMessageFromDictionary:messagePayload context:context];
            }

            [responseMessageIDs addObject:messageID];
        }

        // Delete server-side deleted messages
        NSPredicate *deletedPredicate = [NSPredicate predicateWithFormat:@"NOT (messageID IN %@)", responseMessageIDs];
        [self.inboxDBManager fetchMessagesWithPredicate:deletedPredicate
                                                context:context
                                      completionHandler:^(NSArray *deletedMessages){
             if (deletedMessages.count) {
                 UA_LDEBUG(@"Server deleted messages: %@", deletedMessages);
                 [self.inboxDBManager deleteMessages:deletedMessages context:context];
             }
        }];

        if (completionHandler) {
            completionHandler();
        }
    }];
}

/**
 * Pre-fetches messages on the private context.
 * @param completionHandler Optional completion handler taking the pre-fetched messages as an argument.
 */
- (void)prefetchMessagesWithCompletionHandler:(void (^)(NSArray *messages))completionHandler {
    NSString *predicateFormat = @"(messageExpiration == nil || messageExpiration >= %@) && (deletedClient == NO || deletedClient == nil)";
    NSPredicate *predicate = [NSPredicate predicateWithFormat:predicateFormat, [NSDate date]];
    [self.inboxDBManager fetchMessagesWithPredicate:predicate context:self.inboxDBManager.privateContext completionHandler:^(NSArray *messages) {
        completionHandler(messages);
    }];
}

/**
 * Refreshes the publicly exposed inbox messages, by prefetching on the private
 * context and then updating on the main context.
 *
 * @param completionHandler Optional completion handler.
 */
- (void)refreshInboxWithCompletionHandler:(void (^)())completionHandler {
    [self prefetchMessagesWithCompletionHandler:^(NSArray *messages){
        NSArray *objectIDs = [messages valueForKeyPath:@"data.objectID"];

        NSManagedObjectContext *context = self.inboxDBManager.mainContext;

        // Use the prefetch results to fetch the messages on the main context
        [self.inboxDBManager fetchMessagesWithPredicate:[NSPredicate predicateWithFormat:@"self IN %@", objectIDs]
                                                context:context
                                      completionHandler:^(NSArray *messages) {

              NSInteger unreadCount = 0;

              for (UAInboxMessage *msg in messages) {
                  msg.inbox = self;
                  if (msg.unread) {
                      unreadCount ++;
                  }

                  // Add messsage's body url to the cachable urls
                  [UAURLProtocol addCachableURL:msg.messageBodyURL];
              }

              UA_LINFO(@"Inbox messages updated.");

              UA_LDEBUG(@"Loaded saved messages: %@.", messages);
              self.unreadCount = unreadCount;
              self.messages = [NSArray arrayWithArray:messages];
              
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
    [self.inboxDBManager fetchMessagesWithPredicate:[NSPredicate predicateWithFormat:@"unreadClient == NO && unread == YES"]
                                            context:self.inboxDBManager.privateContext
                                  completionHandler:^(NSArray *locallyReadMessages) {
        if (!locallyReadMessages.count) {
            // Nothing to do
            return;
        }

        UA_LDEBUG(@"Synchronizing locally read messages %@ on server.", locallyReadMessages);

        NSManagedObjectContext *context = self.inboxDBManager.privateContext;

        [self.client performBatchMarkAsReadForMessages:locallyReadMessages onSuccess:^{

            // Mark the messages as read on the private context
            [context performBlock:^{
                for (UAInboxMessage *message in locallyReadMessages) {
                    UA_LDEBUG(@"Successfully synchronized locally read messages on server.");

                    if (!message.data.isGone) {
                        message.data.unread = NO;
                    }
                }

                [context save:nil];
            }];

        } onFailure:^() {
            UA_LDEBUG(@"Failed to synchronize locally read messages on server.");
        }];

    }];
}

/**
 * Synchronizes local deleted message state with the server, on the private context.
 */
- (void)syncDeletedMessageState {
    [self.inboxDBManager fetchMessagesWithPredicate:[NSPredicate predicateWithFormat:@"deletedClient == YES"]
                                            context:self.inboxDBManager.privateContext
                                  completionHandler:^(NSArray *locallyDeletedMessages) {
        if (!locallyDeletedMessages.count) {
           // Nothing to do
           return;
        }

        UA_LDEBUG(@"Synchronizing locally deleted messages %@ on server.", locallyDeletedMessages);

        [self.client performBatchDeleteForMessages:locallyDeletedMessages onSuccess:^{
            UA_LDEBUG(@"Successfully synchronized locally deleted messages on server.");
        } onFailure:^() {
            UA_LDEBUG(@"Failed to synchronize locally deleted messages on server.");
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

@end
