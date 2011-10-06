/*
Copyright 2009-2011 Urban Airship Inc. All rights reserved.

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
#import "UAInboxMessage.h"
#import "UAInboxDBManager.h"
#import "UAUtils.h"
#import "UAUser.h"
#import "UA_ASIHTTPRequest.h"
#import "UA_SBJSON.h"

/*
 * Private methods
 */
@interface UAInboxMessageList()

- (void)loadSavedMessages;

- (void)requestWentWrong:(UA_ASIHTTPRequest *)request;

- (void)messageListFailed:(UA_ASIHTTPRequest *)request;
- (void)messageListReady:(UA_ASIHTTPRequest *)request;

- (void)batchUpdateFinished:(UA_ASIHTTPRequest *)request;
- (void)batchUpdateFailed:(UA_ASIHTTPRequest *)request;

@property(assign) int nRetrieving;

@end

@implementation UAInboxMessageList

@synthesize messages;
@synthesize unreadCount;
@synthesize nRetrieving;
@synthesize isBatchUpdating;

#pragma mark Create Inbox

static UAInboxMessageList *_messageList = nil;

- (void)dealloc {
    RELEASE_SAFELY(messages);
    [super dealloc];
}

+ (void)land {
    if (_messageList) {
        if (_messageList.isRetrieving || _messageList.isBatchUpdating) {
            UALOG(@"Force quit now may cause crash if UA_ASIRequest is alive.");
            //TODO: kill request?
        }
        RELEASE_SAFELY(_messageList);
    }
}

+ (UAInboxMessageList *)shared {
    
    @synchronized(self) {
        if(_messageList == nil) {
            _messageList = [[UAInboxMessageList alloc] init];
            _messageList.unreadCount = -1;
            _messageList.nRetrieving = 0;
            _messageList.isBatchUpdating = NO;
        }
    }
    
    return _messageList;
}

- (BOOL)isRetrieving {
    return nRetrieving > 0;
}

#pragma mark Update/Delete/Mark Messages

- (void)loadSavedMessages {
    
    UALOG(@"before retrieve saved messages: %@", messages);
    NSMutableArray *savedMessages = [[UAInboxDBManager shared] getMessagesForUser:[UAUser defaultUser].username App:[[UAirship shared] appId]];
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

    NSString *lastMessage = nil;
    if ([messages count] > 0) {
        lastMessage = [[messages objectAtIndex: 0] messageID];
    }
    NSString *queryString = @"";
    if (lastMessage != nil) {
        queryString = [NSString stringWithFormat: @"?since=%@", lastMessage];
    }
    
	//TODO: standardize on a single create user url method?
    NSString *urlString = [NSString stringWithFormat: @"%@%@%@%@%@",
                           [[UAirship shared] server], @"/api/user/", [UAUser defaultUser].username ,@"/messages/", queryString];
    UALOG(@"%@",urlString);
    NSURL *requestUrl = [NSURL URLWithString: urlString];

    UA_ASIHTTPRequest *request = [UAUtils userRequestWithURL:requestUrl
                                                      method:@"GET"
                                                    delegate:self
                                                      finish:@selector(messageListReady:)
                                                        fail:@selector(messageListFailed:)];
    
    self.nRetrieving++;
    [request startAsynchronous];

    
}

- (void)messageListReady:(UA_ASIHTTPRequest *)request {
    
    if ([request responseStatusCode] != 200) {
        [self messageListFailed:request];
        return;
    }
    
    self.nRetrieving--;
	
    UA_SBJsonParser *parser = [[UA_SBJsonParser alloc] init];
    NSDictionary *jsonResponse = [parser objectWithString: [request responseString]];
    UALOG(@"Retrieved Messages: %@", [request responseString]);
    [parser release];
    
    // Convert dictionary to objects for convenience
    NSMutableArray *newMessages = [NSMutableArray array];
    for (NSDictionary *message in [jsonResponse objectForKey:@"messages"]) {
        UAInboxMessage *tmp = [[UAInboxMessage alloc] initWithDict:message inbox:self];
        [newMessages addObject:tmp];
        [tmp release];
    }

    if (newMessages.count > 0) {
        NSSortDescriptor* dateDescriptor = [[[NSSortDescriptor alloc] initWithKey:@"messageSent"
                                                                        ascending:YES] autorelease];
        
        //TODO: this flow seems terribly backwards
        NSArray *sortDescriptors = [NSArray arrayWithObject:dateDescriptor];
        [newMessages sortUsingDescriptors:sortDescriptors];

        [newMessages removeObjectsInArray:messages];
        for (UAInboxMessage *msg in newMessages) {
            [messages insertObject:msg atIndex:0];
        }
    }

    [[UAInboxDBManager shared] addMessages:newMessages forUser:[UAUser defaultUser].username App:[[UAirship shared] appId]];
    unreadCount = [[jsonResponse objectForKey: @"badge"] intValue];

    UALOG(@"after retrieveMessageList, messages: %@", messages);
    if (self.nRetrieving == 0) {
        [self notifyObservers:@selector(messageListLoaded)];
    }
}

- (void)messageListFailed:(UA_ASIHTTPRequest *)request {
    self.nRetrieving--;
    [self requestWentWrong:request];
    if (self.nRetrieving == 0) {
        [self notifyObservers:@selector(inboxLoadFailed)];
    }
}

- (void)performBatchUpdateCommand:(UABatchUpdateCommand)command withMessageIndexSet:(NSIndexSet *)messageIndexSet {

    NSURL *requestUrl = nil;
    NSDictionary *data = nil;
    NSArray *updateMessageArray = [messages objectsAtIndexes:messageIndexSet];
    NSArray *updateMessageURLs = [updateMessageArray valueForKeyPath:@"messageURL.absoluteString"];
    UALOG(@"%@", updateMessageURLs);

    if (command == UABatchDeleteMessages) {
        NSString *urlString = [NSString stringWithFormat:@"%@%@%@%@",
                               [UAirship shared].server,
                               @"/api/user/",
                               [UAUser defaultUser].username,
                               @"/messages/delete/"];
        requestUrl = [NSURL URLWithString:urlString];
        UALOG(@"batch delete url: %@", requestUrl);

        data = [NSDictionary dictionaryWithObject:updateMessageURLs forKey:@"delete"];

    } else if (command == UABatchReadMessages) {
        NSString *urlString = [NSString stringWithFormat:@"%@%@%@%@",
                               [UAirship shared].server,
                               @"/api/user/",
                               [UAUser defaultUser].username,
                               @"/messages/unread/"];
        requestUrl = [NSURL URLWithString:urlString];
        UALOG(@"batch mark as read url: %@", requestUrl);

        data = [NSDictionary dictionaryWithObject:updateMessageURLs forKey:@"mark_as_read"];
    } else {
        UALOG("command=%d is invalid.", command);
        return;
    }
    self.isBatchUpdating = YES;
    [self notifyObservers: @selector(messageListWillLoad)];

    UA_SBJsonWriter *writer = [UA_SBJsonWriter new];
    NSString* body = [writer stringWithObject:data];
    [writer release];

    UA_ASIHTTPRequest *request = [UAUtils userRequestWithURL:requestUrl
                                                      method:@"POST"
                                                    delegate:self
                                                      finish:@selector(batchUpdateFinished:)
                                                        fail:@selector(batchUpdateFailed:)];
    
    request.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                            [NSNumber numberWithInt:command], @"command",
                            updateMessageArray, @"messages",
                            nil];
    
    [request addRequestHeader:@"Content-Type" value:@"application/json"];
    [request appendPostData:[body dataUsingEncoding:NSUTF8StringEncoding]];
    [request startAsynchronous];

}

- (void)batchUpdateFinished:(UA_ASIHTTPRequest*)request {
    
    self.isBatchUpdating = NO;

    id option = [request.userInfo objectForKey:@"command"];
    
    NSArray *updateMessageArray = [request.userInfo objectForKey:@"messages"];

    if (request.responseStatusCode != 200) {
        UALOG(@"Server error during batch update messages");
        if ([option intValue] == UABatchDeleteMessages) {
            [self notifyObservers:@selector(batchDeleteFailed)];
        } else if ([option intValue] == UABatchReadMessages) {
            [self notifyObservers:@selector(batchMarkAsReadFailed)];
        }
        
        return;
    }
    
    for (UAInboxMessage *msg in updateMessageArray) {
        if (msg.unread) {
            msg.unread = NO;
            self.unreadCount -= 1;
        }
    }

    if ([option intValue] == UABatchDeleteMessages) {
        [messages removeObjectsInArray:updateMessageArray];
        // TODO: add delete to sync
        [[UAInboxDBManager shared] deleteMessages:updateMessageArray];
        [self notifyObservers:@selector(batchDeleteFinished)];
    } else if ([option intValue] == UABatchReadMessages) {
        [[UAInboxDBManager shared] updateMessagesAsRead:updateMessageArray];
        [self notifyObservers:@selector(batchMarkAsReadFinished)];
    }
}

- (void)batchUpdateFailed:(UA_ASIHTTPRequest*)request {
    self.isBatchUpdating = NO;

    [self requestWentWrong:request];
    
    id option = [request.userInfo objectForKey:@"command"];
    if ([option intValue] == UABatchDeleteMessages) {
        [self notifyObservers:@selector(batchDeleteFailed)];
    } else if ([option intValue] == UABatchReadMessages) {
        [self notifyObservers:@selector(batchMarkAsReadFailed)];
    }
}

- (void)requestWentWrong:(UA_ASIHTTPRequest *)request {
    UALOG(@"Inbox Message List Request Failed: %@", [[request error] localizedDescription]);
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
