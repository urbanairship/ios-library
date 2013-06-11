/*
Copyright 2009-2012 Urban Airship Inc. All rights reserved.

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

#import "UAirship.h"
#import "UAInboxClient.h"
#import "UAInboxMessage.h"
#import "UAInboxDBManager.h"
#import "UAUtils.h"
#import "UAUser.h"
#import "UAHTTPConnection.h"
#import "UA_SBJSON.h"

/*
 * Private methods
 */
@interface UAInboxMessageList()

- (void)loadSavedMessages;

@property(nonatomic, retain) UAInboxClient *client;
@property(nonatomic, assign) BOOL isRetrieving;

@end

@implementation UAInboxMessageList

@synthesize messages;
@synthesize unreadCount;
@synthesize isBatchUpdating;

#pragma mark Create Inbox

static UAInboxMessageList *_messageList = nil;

- (void)dealloc {
    RELEASE_SAFELY(messages);
    self.client = nil;
    [super dealloc];
}

+ (void)land {
    if (_messageList) {
        if (_messageList.isRetrieving || _messageList.isBatchUpdating) {
            _messageList.client = nil;
        }
        RELEASE_SAFELY(_messageList);
    }
}

+ (UAInboxMessageList *)shared {
    
    @synchronized(self) {
        if(_messageList == nil) {
            _messageList = [[UAInboxMessageList alloc] init];
            _messageList.unreadCount = -1;
            _messageList.isBatchUpdating = NO;

            _messageList.client = [[[UAInboxClient alloc] init] autorelease];
        }
    }
    
    return _messageList;
}

#pragma mark Update/Delete/Mark Messages

- (void)loadSavedMessages {
    
    UALOG(@"before retrieve saved messages: %@", messages);
    NSMutableArray *savedMessages = [[UAInboxDBManager shared] getMessagesForUser:[UAUser defaultUser].username app:[[UAirship shared] appId]];
    for (UAInboxMessage *msg in savedMessages) {
        msg.inbox = self;
    }
    self.messages = [[[NSMutableArray alloc] initWithArray:savedMessages] autorelease];
    UALOG(@"after retrieve saved messages: %@", messages);
    
}

- (void)retrieveMessageList {
    
	if(![[UAUser defaultUser] defaultUserCreated]) {
		UALOG("Waiting for User Update message to retrieveMessageList");
		[[UAUser defaultUser] addObserver:self];
		return;
	}

    [self notifyObservers: @selector(messageListWillLoad)];
    [self loadSavedMessages];

    self.isRetrieving = YES;

    [self.client retrieveMessageListOnSuccess:^(NSMutableArray *newMessages, NSInteger unread){

        self.isRetrieving = NO;

        [[UAInboxDBManager shared] deleteMessages:messages];
        [[UAInboxDBManager shared] addMessages:newMessages forUser:[UAUser defaultUser].username app:[[UAirship shared] appId]];
        self.messages = newMessages;

        unreadCount = unread;

        UALOG(@"after retrieveMessageList, messages: %@", messages);
        [self notifyObservers:@selector(messageListLoaded)];
    } onFailure:^(UAHTTPRequest *request){
        self.isRetrieving = NO;

        UA_LDEBUG(@"Retrieve message list failed with status: %d", request.response.statusCode);
        [self notifyObservers:@selector(inboxLoadFailed)];
    }];
}

- (void)performBatchUpdateCommand:(UABatchUpdateCommand)command withMessageIndexSet:(NSIndexSet *)messageIndexSet {

    if (command != UABatchDeleteMessages && command != UABatchReadMessages) {
        UA_LERR(@"command=%d is invalid.", command);
        return;
    }

    NSArray *updateMessageArray = [messages objectsAtIndexes:messageIndexSet];
    
    self.isBatchUpdating = YES;
    [self notifyObservers: @selector(messageListWillLoad)];

    [self.client
     performBatchUpdateCommand:command
     forMessages:updateMessageArray
     onSuccess:^{
         self.isBatchUpdating = NO;

         for (UAInboxMessage *msg in updateMessageArray) {
             if (msg.unread) {
                 msg.unread = NO;
                 self.unreadCount -= 1;
             }
         }

         if (command == UABatchDeleteMessages) {
             [messages removeObjectsInArray:updateMessageArray];
             // TODO: add delete to sync
             [[UAInboxDBManager shared] deleteMessages:updateMessageArray];
             [self notifyObservers:@selector(batchDeleteFinished)];

         } else if (command == UABatchReadMessages) {
             [[UAInboxDBManager shared] updateMessagesAsRead:updateMessageArray];
             [self notifyObservers:@selector(batchMarkAsReadFinished)];
         }
     } onFailure:^(UAHTTPRequest *request){
         self.isBatchUpdating = NO;

         UA_LDEBUG(@"Perform batch update failed with status: %d", request.response.statusCode);
         if (command == UABatchDeleteMessages) {
             [self notifyObservers:@selector(batchDeleteFailed)];
         } else if (command == UABatchReadMessages) {
             [self notifyObservers:@selector(batchMarkAsReadFailed)];
         }
     }];
}

#pragma mark -
#pragma mark Get messages

- (int)messageCount {
    return [messages count];
}

- (UAInboxMessage *)messageForID:(NSString *)mid {
    for (UAInboxMessage *msg in messages) {
        if ([msg.messageID isEqualToString:mid]) {
            return msg;
        }
    }
    return nil;
}

- (UAInboxMessage *)messageAtIndex:(int)index {
    if (index < 0 || index >= [messages count]) {
        UALOG("Load message(index=%d, count=%d) error.", index, [messages count]);
        return nil;
    }
    return [messages objectAtIndex:index];
}

- (int)indexOfMessage:(UAInboxMessage *)message {
    return [messages indexOfObject:message];
}

#pragma mark -
#pragma mark UAUserObserver

- (void)userUpdated {
    UALOG(@"UAInboxMessageList notified: userUpdated");
	if([[UAUser defaultUser] defaultUserCreated]) {
		[[UAUser defaultUser] removeObserver:self];
		[self retrieveMessageList];
	}
}

@end
