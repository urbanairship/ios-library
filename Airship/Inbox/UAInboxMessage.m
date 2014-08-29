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

#import "UAInboxMessage+Internal.h"
#import "UAInbox.h"
#import "UAInboxMessageData.h"
#import "UAInboxAPIClient.h"
#import "UAInboxDBManager.h"
#import "UAInboxMessageList+Internal.h"

@implementation UAInboxMessage

- (instancetype)initWithMessageData:(UAInboxMessageData *)data {
    self = [super init];
    if (self) {
        self.data = data;
    }
    return self;
}

+ (instancetype)messageWithData:(UAInboxMessageData *)data {
    return [[self alloc] initWithMessageData:data];
}

#pragma mark -
#pragma mark NSObject methods

// NSObject override
- (NSString *)description {
    return [NSString stringWithFormat: @"%@ - %@", self.messageID, self.title];
}

#pragma mark -
#pragma mark Mark As Read Delegate Methods


- (UADisposable *)markMessageReadWithCompletionHandler:(UAInboxMessageCallbackBlock)completionHandler {
    if (!self.unread) {
        return nil;
    }

    return [self.inbox markMessagesRead:@[self] completionHandler:^{
        if (completionHandler) {
            completionHandler(self);
        }
    }];
}

- (UADisposable *)markAsReadWithSuccessBlock:(UAInboxMessageCallbackBlock)successBlock
                            withFailureBlock:(UAInboxMessageCallbackBlock)failureBlock {

    return [self markMessageReadWithCompletionHandler:^(UAInboxMessage *message) {
        if (successBlock) {
            successBlock(message);
        }
    }];
}

- (UADisposable *)markAsReadWithDelegate:(id<UAInboxMessageListDelegate>)delegate {
    __weak id<UAInboxMessageListDelegate> weakDelegate = delegate;

    return [self markMessageReadWithCompletionHandler:^(UAInboxMessage *message){
        id<UAInboxMessageListDelegate> strongDelegate = weakDelegate;
        if ([strongDelegate respondsToSelector:@selector(singleMessageMarkAsReadFinished:)]) {
            [strongDelegate singleMessageMarkAsReadFinished:message];
        }
    }];
}

- (BOOL)isExpired {
    if (self.messageExpiration) {
        NSComparisonResult result = [self.messageExpiration compare:[NSDate date]];
        return (result == NSOrderedAscending || result == NSOrderedSame);
    }

    return NO;
}

- (NSString *)messageID {
    return self.data.messageID;
}

- (NSURL *)messageBodyURL {
    return self.data.messageBodyURL;
}

- (NSURL *)messageURL {
    return self.data.messageURL;
}

- (NSString *)contentType {
    return self.data.contentType;
}

- (BOOL)unread {
    return self.data.unreadClient && self.data.unread;
}

- (NSDate *)messageSent {
    return self.data.messageSent;
}

- (NSDate *)messageExpiration {
    return self.data.messageExpiration;
}

- (NSString *)title {
    return self.data.title;
}

- (NSDictionary *)extra {
    return self.data.extra;
}

- (NSDictionary *)rawMessageObject {
    return self.data.rawMessageObject;
}

@end
