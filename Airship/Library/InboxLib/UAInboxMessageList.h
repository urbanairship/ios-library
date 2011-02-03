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

#import "UAInbox.h"
#import "UAInboxMessageListObserver.h"
#import "UAInboxMessage.h"
#import "UAUser.h"

typedef enum {
    UABatchReadMessages,
    UABatchDeleteMessages,
} UABatchUpdateCommand;

typedef enum {
    UABatchReadMessagesSuccess,
    UABatchDeleteMessagesSuccess,
    UABatchReadMessagesFailed,
    UABatchDeleteMessagesFailed,
} UABatchUpdateResult;

@class UAInboxMessage;

@interface UAInboxMessageList : UAObservable <UAUserObserver> {
    NSMutableArray* messages;
    // If unreadCount < 0, that means the message list hasn't retrieved.
    int unreadCount;
    int isRetriving;
    BOOL isBatchUpdating;
}

+ (UAInboxMessageList*)defaultInbox;
+ (void)land;

- (void)retrieveMessageList;
- (BOOL)batchUpdate:(NSIndexSet *)messageIDs option:(UABatchUpdateCommand)option;
- (BOOL)isBusying;

- (int)messageCount;
- (UAInboxMessage *)messageForID:(NSString *)mid;
- (UAInboxMessage*)messageAtIndex:(int)index;
- (int)indexOfMessage:(UAInboxMessage *)message;

- (void)requestWentWrong:(UA_ASIHTTPRequest *)request;

@property(nonatomic, retain) NSMutableArray* messages;
@property(assign) int unreadCount;
@property(assign) int isRetrieving;
@property(assign) BOOL isBatchUpdating;

@end
