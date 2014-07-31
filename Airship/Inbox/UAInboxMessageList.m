/*
Copyright 2009-2014 Urban Airship Inc. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
list of conditions and the following disclaimer.

2. Redistributions in binaryform must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided withthe distribution.

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

#import "UAInboxMessageList.h"
#import "UAInboxMessageList+Internal.h"

#import "UAirship.h"
#import "UAConfig.h"
#import "UADisposable.h"
#import "UAInbox.h"
#import "UAInboxAPIClient.h"
#import "UAInboxMessageListObserver.h"
#import "UAInboxMessageListDelegate.h"
#import "UAInboxMessage.h"
#import "UAInboxDBManager+Internal.h"
#import "UAUtils.h"
#import "UAUser.h"
#import "UAHTTPConnection.h"
#import "UAURLProtocol.h"

NSString * const UAInboxMessageListWillUpdateNotification = @"com.urbanairship.notification.message_list_will_update";
NSString * const UAInboxMessageListUpdatedNotification = @"com.urbanairship.notification.message_list_updated";

/*
 * Private methods
 */
@interface UAInboxMessageList()

- (void)loadSavedMessages;

@property(nonatomic, assign) BOOL isRetrieving;

@end

@implementation UAInboxMessageList

#pragma mark Create Inbox

- (instancetype)init {
    self = [super init];

    if (self) {
        self.unreadCount = -1;
        self.isBatchUpdating = NO;
        self.client = [[UAInboxAPIClient alloc] init];
    }
    return self;
}

- (void)dealloc {
    self.messages = nil;
}


+ (UAInboxMessageList *)shared {

    return [UAInbox shared].messageList;
}

#pragma mark NSNotificationCenter helper methods

- (void)sendMessageListWillUpdateNotification {
    [[NSNotificationCenter defaultCenter] postNotificationName:UAInboxMessageListWillUpdateNotification object:nil];
}

- (void)sendMessageListUpdatedNotification {
    [[NSNotificationCenter defaultCenter] postNotificationName:UAInboxMessageListUpdatedNotification object:nil];
}

#pragma mark Update/Delete/Mark Messages

- (void)loadSavedMessages {
    [[UAInboxDBManager shared] deleteExpiredMessages];
    NSMutableArray *savedMessages = [[[UAInboxDBManager shared] getMessages] mutableCopy];

    self.unreadCount = 0;

    for (UAInboxMessage *msg in savedMessages) {
        msg.inbox = self;
        if (msg.unread) {
            self.unreadCount ++;
        }
    }

    self.messages = [[NSMutableArray alloc] initWithArray:savedMessages];
    UA_LDEBUG(@"Loaded saved messages: %@.", self.messages);
}

- (UADisposable *)retrieveMessageListWithSuccessBlock:(UAInboxMessageListCallbackBlock)successBlock
                                  withFailureBlock:(UAInboxMessageListCallbackBlock)failureBlock {
    if (![[UAUser defaultUser] defaultUserCreated]) {
        return nil;
    }

    UA_LDEBUG("Retrieving message list.");

    [self notifyObservers: @selector(messageListWillLoad)];
    [self sendMessageListWillUpdateNotification];

    [self loadSavedMessages];

    self.isRetrieving = YES;

    __block BOOL isCallbackCancelled = NO;

    UADisposable *disposable = [UADisposable disposableWithBlock:^{
        isCallbackCancelled = YES;
    }];

    [self.client retrieveMessageListOnSuccess:^(NSMutableArray *newMessages, NSUInteger unread){
        self.isRetrieving = NO;

        self.messages = newMessages;
        self.unreadCount = (NSInteger)unread;

        UA_LDEBUG(@"Retrieve message list succeeded with messages: %@", self.messages);
        if (successBlock && !isCallbackCancelled) {
            successBlock();
        }
        [self notifyObservers:@selector(messageListLoaded)];
        [self sendMessageListUpdatedNotification];
    } onFailure:^(UAHTTPRequest *request){
        self.isRetrieving = NO;

        UA_LDEBUG(@"Retrieve message list failed with status: %ld", (long)request.response.statusCode);
        if (failureBlock && !isCallbackCancelled) {
            failureBlock();
        }

        [self notifyObservers:@selector(inboxLoadFailed)];
        [self sendMessageListUpdatedNotification];
    }];

    return disposable;
}

- (UADisposable *)retrieveMessageListWithDelegate:(id<UAInboxMessageListDelegate>)delegate {
    __weak id<UAInboxMessageListDelegate> weakDelegate = delegate;

    return [self retrieveMessageListWithSuccessBlock:^{
        id<UAInboxMessageListDelegate> strongDelegate = weakDelegate;
        if ([strongDelegate respondsToSelector:@selector(messageListLoadSucceeded)]) {
            [strongDelegate messageListLoadSucceeded];
        }
    } withFailureBlock:^{
        id<UAInboxMessageListDelegate> strongDelegate = weakDelegate;
        if ([strongDelegate respondsToSelector:@selector(messageListLoadFailed)]){
            [strongDelegate messageListLoadFailed];
        }
    }];
}

- (void)retrieveMessageList {
    [self retrieveMessageListWithSuccessBlock:nil withFailureBlock:nil];
}

- (UADisposable *)performBatchUpdateCommand:(UABatchUpdateCommand)command
                        withMessageIndexSet:(NSIndexSet *)messageIndexSet
                           withSuccessBlock:(UAInboxMessageListCallbackBlock)successBlock
                           withFailureBlock:(UAInboxMessageListCallbackBlock)failureBlock {
    if (command != UABatchDeleteMessages && command != UABatchReadMessages) {
        UA_LWARN(@"Unable to perform batch update with invalid command type: %d", command);
        return nil;
    }

    NSArray *updateMessageArray = [self.messages objectsAtIndexes:messageIndexSet];

    self.isBatchUpdating = YES;
    [self notifyObservers: @selector(messageListWillLoad)];
    [self sendMessageListWillUpdateNotification];

    __block BOOL isCallbackCancelled = NO;

    UADisposable *disposable = [UADisposable disposableWithBlock:^{
        isCallbackCancelled = YES;
    }];

    void (^updateUnreadCount)(void) = ^{
        for (UAInboxMessage *msg in updateMessageArray) {
            if (msg.unread) {
                msg.unread = NO;
                self.unreadCount -= 1;
            }
        }
    };
    
    void (^succeed)(void) = ^{
        self.isBatchUpdating = NO;

        if (successBlock && !isCallbackCancelled) {
            successBlock();
        }
        [self sendMessageListUpdatedNotification];
    };

    void (^fail)(UAHTTPRequest *) = ^(UAHTTPRequest *request){
        self.isBatchUpdating = NO;
        UA_LDEBUG(@"Perform batch update failed with status: %ld", (long)request.response.statusCode);
        if (failureBlock && !isCallbackCancelled) {
            failureBlock();
        }
        [self sendMessageListUpdatedNotification];
    };

    if (command == UABatchDeleteMessages) {
        UA_LDEBUG("Deleting messages: %@", updateMessageArray);
        [self.client performBatchDeleteForMessages:updateMessageArray onSuccess:^{
            updateUnreadCount();
            [self.messages removeObjectsInArray:updateMessageArray];
            [[UAInboxDBManager shared] deleteMessages:updateMessageArray];
            [self notifyObservers:@selector(batchDeleteFinished)];
            succeed();
        }onFailure:^(UAHTTPRequest *request){
            [self notifyObservers:@selector(batchDeleteFailed)];
            fail(request);
        }];

    } else if (command == UABatchReadMessages) {
        UA_LDEBUG("Marking messages as read: %@", updateMessageArray);
        [self.client performBatchMarkAsReadForMessages:updateMessageArray onSuccess:^{
            updateUnreadCount();
            [[UAInboxDBManager shared] saveContext];
            [self notifyObservers:@selector(batchMarkAsReadFinished)];
            succeed();
        }onFailure:^(UAHTTPRequest *request){
            [self notifyObservers:@selector(batchMarkAsReadFailed)];
            fail(request);
        }];
    }

    return disposable;
}

- (UADisposable *)performBatchUpdateCommand:(UABatchUpdateCommand)command
              withMessageIndexSet:(NSIndexSet *)messageIndexSet
                     withDelegate:(id<UAInboxMessageListDelegate>)delegate {

    __weak id<UAInboxMessageListDelegate> weakDelegate = delegate;

    return [self performBatchUpdateCommand:command withMessageIndexSet:messageIndexSet withSuccessBlock:^{
        id<UAInboxMessageListDelegate> strongDelegate = weakDelegate;
        if (command == UABatchDeleteMessages) {
            if ([strongDelegate respondsToSelector:@selector(batchDeleteFinished)]) {
                [strongDelegate batchDeleteFinished];
            }
        } else if (command == UABatchReadMessages) {
            if ([strongDelegate respondsToSelector:@selector(batchMarkAsReadFinished)]) {
                [strongDelegate batchMarkAsReadFinished];
            }
        }
    } withFailureBlock:^{
        id<UAInboxMessageListDelegate> strongDelegate = weakDelegate;
        if (command == UABatchDeleteMessages) {
            if ([strongDelegate respondsToSelector:@selector(batchDeleteFailed)]) {
                [strongDelegate batchDeleteFailed];
            }
        } else if (command == UABatchReadMessages) {
            if ([strongDelegate respondsToSelector:@selector(batchMarkAsReadFailed)]) {
                [strongDelegate batchMarkAsReadFailed];
            }
        }
    }];
}

- (void)performBatchUpdateCommand:(UABatchUpdateCommand)command withMessageIndexSet:(NSIndexSet *)messageIndexSet {
    [self performBatchUpdateCommand:command
                withMessageIndexSet:messageIndexSet
                   withSuccessBlock:nil
                   withFailureBlock:nil];
}

#pragma mark -
#pragma mark Get messages

- (NSUInteger)messageCount {
    return [self.messages count];
}

- (UAInboxMessage *)messageForID:(NSString *)mid {
    for (UAInboxMessage *msg in self.messages) {
        if ([msg.messageID isEqualToString:mid]) {
            return msg;
        }
    }
    return nil;
}

- (UAInboxMessage *)messageAtIndex:(NSUInteger)index {
    if (index >= [self.messages count]) {
        UA_LWARN("Load message(index=%lu, count=%lu) error.", (unsigned long)index, (unsigned long)[self.messages count]);
        return nil;
    }
    return [self.messages objectAtIndex:index];
}

- (NSUInteger)indexOfMessage:(UAInboxMessage *)message {
    return [self.messages indexOfObject:message];
}

#pragma mark -
#pragma mark set messages
- (void)setMessages:(NSMutableArray *)messages {
    // Sort the messages by date
    if (messages.count > 0) {
        NSSortDescriptor* dateDescriptor = [[NSSortDescriptor alloc] initWithKey:@"messageSent"
                                                                       ascending:NO];
        NSArray *sortDescriptors = [NSArray arrayWithObject:dateDescriptor];
        [messages sortUsingDescriptors:sortDescriptors];
    }

    // Add messsage's body url to the cachable urls
    for (UAInboxMessage *message in messages) {
        [UAURLProtocol addCachableURL:message.messageBodyURL];
    }

    _messages = messages;
}


@end
