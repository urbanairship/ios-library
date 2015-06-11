/*
 Copyright 2009-2015 Urban Airship Inc. All rights reserved.

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

#import "UAInboxMessageList+Internal.h"

#import "UAirship.h"
#import "UAConfig.h"
#import "UADisposable.h"
#import "UAInbox.h"
#import "UAInboxAPIClient.h"
#import "UAInboxMessage+Internal.h"
#import "UAInboxDBManager+Internal.h"
#import "UAUtils.h"
#import "UAUser.h"
#import "UAHTTPConnection.h"
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

#pragma mark Custom setters

- (void)setMessages:(NSArray *)messages {
    @synchronized(self) {
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
}

- (NSArray *)messages {
    @synchronized(self) {
        return _messages;
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

    void (^completionBlock)() = ^{
        if (self.retrieveOperationCount > 0) {
            self.retrieveOperationCount--;
        }

        if (retrieveMessageListSuccessBlock) {
            retrieveMessageListSuccessBlock();
        }

        [self sendMessageListUpdatedNotification];
    };

    // Fetch new messages
    [self.client retrieveMessageListOnSuccess:^(NSInteger status, NSArray *messages, NSInteger unread) {
        // Sync client state
        [self syncLocalMessageState];

        if (status == 200) {
            UA_LDEBUG(@"Refreshing message list.");

            [self syncMessagesWithResponse:messages completionHandler:^{
                [self refreshInboxWithCompletionHandler:completionBlock];
            }];
        } else {
            UA_LDEBUG(@"Retrieve message list succeeded with messages: %@", self.messages);
            completionBlock();
        }

    } onFailure:^(UAHTTPRequest *request){
        UA_LDEBUG(@"Retrieve message list failed with status: %ld", (long)request.response.statusCode);
        completionBlock();
    }];

    return disposable;
}


- (UADisposable *)markMessagesRead:(NSArray *)messages completionHandler:(UAInboxMessageListCallbackBlock)completionHandler {
    self.batchOperationCount++;
    [self sendMessageListWillUpdateNotification];

    __block UAInboxMessageListCallbackBlock inboxMessageListCompletionBlock = completionHandler;
    UADisposable *disposable = [UADisposable disposableWithBlock:^{
        inboxMessageListCompletionBlock = nil;
    }];

    UA_LDEBUG(@"Marking messages as read %@.", messages);
    [self.inboxDBManager.mainContext performBlockAndWait:^{
        for (UAInboxMessage *message in messages) {
            if ([message isKindOfClass:[UAInboxMessage class]] && !message.data.isGone) {
                message.data.unreadClient = NO;
            }
        }

        [self.inboxDBManager.mainContext save:nil];
    }];

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

    return disposable;
}

- (UADisposable *)markMessagesDeleted:(NSArray *)messages completionHandler:(UAInboxMessageListCallbackBlock)completionHandler{
    self.batchOperationCount++;
    [self sendMessageListWillUpdateNotification];

    __block UAInboxMessageListCallbackBlock inboxMessageListCompletionBlock = completionHandler;
    UADisposable *disposable = [UADisposable disposableWithBlock:^{
        inboxMessageListCompletionBlock = nil;
    }];

    UA_LDEBUG(@"Marking messages as deleted %@.", messages);
    [self.inboxDBManager.mainContext performBlockAndWait:^{

        for (UAInboxMessage *message in messages) {
            if ([message isKindOfClass:[UAInboxMessage class]] && !message.data.isGone) {
                message.data.deletedClient = YES;
            }
        }

        [self.inboxDBManager.mainContext save:nil];
    }];


    // Block is dispatched on the main queue
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
 * Fetches messages with a specified predicate, on a given context.
 *
 * @param predicate An NSPredicate querying a subset of messages.
 * @param context The context on which to perform the fetch.
 * @param completionHandler An optional completion handler called when the fetch is complete.
 */
- (void)fetchMessagesWithPredicate:(NSPredicate *)predicate
                           context:(NSManagedObjectContext *)context
                 completionHandler:(UAInboxMessageFetchCompletionHandler)completionHandler {

    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:kUAInboxDBEntityName
                                 inManagedObjectContext:context];

    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"messageSent" ascending:NO];
    request.sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
    request.predicate = predicate;

    [context performBlock:^{
        NSArray *resultData = [context executeFetchRequest:request error:nil];

        NSMutableArray *resultMessages = [NSMutableArray array];
        for (UAInboxMessageData *data in resultData) {
            [resultMessages addObject:[UAInboxMessage messageWithData:data]];
        }

        if (completionHandler) {
            completionHandler(resultMessages);
        }
    }];
}

/**
 * Updates the provided message data object with information contained in the provided dictionary.
 * @param data An instance of UAInboxMessageData.
 @ @param dict An NSDictionary with updated message content.
 */
- (void)updateMessageData:(UAInboxMessageData *)data withDictionary:(NSDictionary *)dict {

    dict = [dict dictionaryWithValuesForKeys:[[dict keysOfEntriesPassingTest:^BOOL(id key, id obj, BOOL *stop) {
        return ![obj isEqual:[NSNull null]];
    }] allObjects]];

    if (!data.isGone) {
        data.messageID = dict[@"message_id"];
        data.contentType = dict[@"content_type"];
        data.title = dict[@"title"];
        data.extra = dict[@"extra"];
        data.messageBodyURL = [NSURL URLWithString:dict[@"message_body_url"]];
        data.messageURL = [NSURL URLWithString:dict[@"message_url"]];
        data.unread = [dict[@"unread"] boolValue];
        data.messageSent = [[UAUtils ISODateFormatterUTC] dateFromString:dict[@"message_sent"]];
        data.rawMessageObject = dict;

        NSString *messageExpiration = dict[@"message_expiry"];
        if (messageExpiration) {
            data.messageExpiration = [[UAUtils ISODateFormatterUTC] dateFromString:messageExpiration];
        } else {
            data.messageExpiration = nil;
        }
    }
}

/**
 * Synchronizes local messages with response from a remote fetch.
 *
 * @param messages The messages returned from a remote fetch.
 * @param completionHandler An optional completion handler run when the sync is complete.
 */
- (void)syncMessagesWithResponse:(NSArray *)messages completionHandler:(void(^)())completionHandler {
    [self.inboxDBManager.privateContext performBlock:^{

        // Track the response messageIDs so we can remove any messages that are
        // no longer in the response.
        NSMutableSet *responseMessageIDs = [NSMutableSet set];

        for (NSDictionary *messagePayload in messages) {
            NSString *messageID = messagePayload[@"message_id"];

            if (!messageID) {
                UA_LDEBUG(@"Missing message ID: %@", messagePayload);
                continue;
            }

            NSFetchRequest *request = [[NSFetchRequest alloc] init];
            request.entity = [NSEntityDescription entityForName:kUAInboxDBEntityName
                                         inManagedObjectContext:self.inboxDBManager.privateContext];
            request.predicate = [NSPredicate predicateWithFormat:@"messageID == %@", messageID];
            request.fetchLimit = 1;

            NSArray *resultData = [self.inboxDBManager.privateContext executeFetchRequest:request error:nil];

            UAInboxMessageData *data;
            if (resultData.count) {
                data = [resultData lastObject];
            } else {
                data = [NSEntityDescription insertNewObjectForEntityForName:kUAInboxDBEntityName
                                                     inManagedObjectContext:self.inboxDBManager.privateContext];
            }

            [self updateMessageData:data withDictionary:messagePayload];

            [responseMessageIDs addObject:messagePayload[@"message_id"]];
        }

        // Delete any messages that are not in the response
        NSFetchRequest *request = [[NSFetchRequest alloc] init];
        NSEntityDescription *entity = [NSEntityDescription entityForName:kUAInboxDBEntityName
                                                  inManagedObjectContext:self.inboxDBManager.privateContext];
        [request setEntity:entity];
        [request setPredicate:[NSPredicate predicateWithFormat:@"NOT (messageID IN %@)", responseMessageIDs]];

        NSArray *deletedMessages = [self.inboxDBManager.privateContext executeFetchRequest:request error:nil];
        for (UAInboxMessageData *data in deletedMessages) {
            UA_LDEBUG(@"Removing messages from coredata: %@", data.messageID);
            [self.inboxDBManager.privateContext deleteObject:data];
        }

        // Save changes
        [self.inboxDBManager.privateContext save:nil];

        if (completionHandler) {
            completionHandler();
        }
    }];
}


/**
 * Updates messages on the main context.
 * @param messages An array of messages bound to the private context
 * @param completionHandler An optional completion handler called when the update is complete.
 */
- (void)updateMessagesOnMainContext:(NSArray *)messages withCompletionHandler:(void (^)(void))completionHandler {
    NSArray *objectIDs = [messages valueForKeyPath:@"data.objectID"];

    // Use the prefetch results to fetch the messages on the main context
    [self fetchMessagesWithPredicate:[NSPredicate predicateWithFormat:@"self IN %@", objectIDs]
                             context:self.inboxDBManager.mainContext
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
}

/**
 * Pre-fetches messages on the private context.
 * @param completionHandler Optional completion handler taking the pre-fetched messages as an argument
 */
- (void)prefetchMessagesWithCompletionHandler:(void (^)(NSArray *messages))completionHandler {
    NSString *predicateFormat = @"(messageExpiration == nil || messageExpiration >= %@) && (deletedClient == NO || deletedClient == nil)";
    NSPredicate *predicate = [NSPredicate predicateWithFormat:predicateFormat, [NSDate date]];
    [self fetchMessagesWithPredicate:predicate context:self.inboxDBManager.privateContext completionHandler:^(NSArray *messages) {
        completionHandler(messages);
    }];
}

/**
 * Refreshes the publically exposed inbox messages, by prefetching on the private
 * context and then updating on the main context.
 *
 * @param completionHandler Optional completion handler.
 */
- (void)refreshInboxWithCompletionHandler:(void (^)())completionHandler {
    [self prefetchMessagesWithCompletionHandler:^(NSArray *messages){
        [self updateMessagesOnMainContext:messages withCompletionHandler:completionHandler];
    }];
}

/**
 * Fetches locally read messages on the private context.
 * @param completionHandler An optional completion handler called when the fetch is complete.
 */
- (void)fetchLocallyReadMessagesWithCompletionHandler:(void (^)(NSArray *messages))completionHandler {
    // Locally read messages
    [self fetchMessagesWithPredicate:[NSPredicate predicateWithFormat:@"unreadClient == NO && unread == YES"]
                             context:self.inboxDBManager.privateContext
                   completionHandler:completionHandler];
}

/**
 * Fetches locally deleted messages on the private context.
 * @param completionHandler An optional completion handler called when the fetch is complete
 */
- (void)fetchLocallyDeletedMessagesWithCompletionHandler:(void (^)(NSArray *messages))completionHandler {
    [self fetchMessagesWithPredicate:[NSPredicate predicateWithFormat:@"deletedClient == YES"]
                             context:self.inboxDBManager.privateContext
                   completionHandler:completionHandler];
}

/**
 * Synchronizes local read messages state with the server.
 */
- (void)syncReadMessageState {
    [self fetchLocallyReadMessagesWithCompletionHandler:^(NSArray *locallyReadMessages) {
        if (!locallyReadMessages.count) {
            // Nothing to do
            return;
        }

        UA_LDEBUG(@"Synchronizing locally read messages %@ on server.", locallyReadMessages);

        [self.client performBatchMarkAsReadForMessages:locallyReadMessages onSuccess:^{

            // Mark the messages as read on the private context
            [self.inboxDBManager.privateContext performBlock:^{
                for (UAInboxMessage *message in locallyReadMessages) {
                    UA_LDEBUG(@"Successfully synchronized locally read messages on server.");

                    if (!message.data.isGone) {
                        message.data.unread = NO;
                    }
                }

                [self.inboxDBManager.privateContext save:nil];
            }];

        } onFailure:^(UAHTTPRequest *request) {
            UA_LDEBUG(@"Failed to synchronize locally read messages on server.");
        }];

    }];
}

/**
 * Synchronizes local deleted message state with the server.
 */
- (void)syncDeletedMessageState {
    [self fetchLocallyDeletedMessagesWithCompletionHandler:^(NSArray *locallyDeletedMessages) {
        if (!locallyDeletedMessages.count) {
           // Nothing to do
           return;
        }

        UA_LDEBUG(@"Synchronizing locally deleted messages %@ on server.", locallyDeletedMessages);

        [self.client performBatchDeleteForMessages:locallyDeletedMessages onSuccess:^{
            UA_LDEBUG(@"Successfully synchronized locally deleted messages on server.");
        } onFailure:^(UAHTTPRequest *request) {
            UA_LDEBUG(@"Failed to synchronize locally deleted messages on server.");
        }];
    }];
}

/**
 * Synchronizes any local read or deleted message state with the server.
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
