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

#import "UAInboxMessage.h"
#import "UAInboxMessage+Internal.h"
#import "UAInbox.h"
#import "UAInboxMessageData.h"
#import "UAInboxAPIClient.h"
#import "UAInboxDBManager.h"

@implementation UAInboxMessage

@synthesize messageID = _messageID;
@synthesize messageBodyURL = _messageBodyURL;
@synthesize messageURL = _messageURL;
@synthesize contentType = _contentType;
@synthesize unread = _unread;
@synthesize messageSent = _messageSent;
@synthesize messageExpiration = _messageExpiration;
@synthesize title = _title;
@synthesize extra = _extra;
@synthesize rawMessageObject = _rawMessageObject;

- (instancetype)initWithMessageData:(UAInboxMessageData *)data {
    self = [super init];
    if (self) {
        self.data = data;
        self.messageID = data.messageID;
        self.messageBodyURL = data.messageBodyURL;
        self.messageURL = data.messageURL;
        self.contentType = data.contentType;
        self.unread = data.unread;
        self.messageSent = data.messageSent;
        self.messageExpiration = data.messageExpiration;
        self.title = data.title;
        self.extra = data.extra;
        self.rawMessageObject = data.rawMessageObject;
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

- (UADisposable *)markAsReadWithSuccessBlock:(UAInboxMessageCallbackBlock)successBlock
                            withFailureBlock:(UAInboxMessageCallbackBlock)failureBlock {

    UAInboxMessageList *strongInbox = self.inbox;

    if (!self.unread || strongInbox.isBatchUpdating) {
        return nil;
    }

    strongInbox.isBatchUpdating = YES;

    __block BOOL isCallbackCancelled = NO;

    UADisposable *disposable = [UADisposable disposableWithBlock:^{
        isCallbackCancelled = YES;
    }];

    UAInboxAPIClient *client = [UAInbox shared].client;

    [client
     markMessageRead:self onSuccess:^{
         if (self.unread) {
             strongInbox.unreadCount = strongInbox.unreadCount - 1;
             self.unread = NO;
             [[UAInboxDBManager shared] saveContext];
         }

         strongInbox.isBatchUpdating = NO;

         [strongInbox notifyObservers:@selector(singleMessageMarkAsReadFinished:) withObject:self];

         if (successBlock && !isCallbackCancelled) {
             successBlock(self);
         }
     } onFailure:^(UAHTTPRequest *request){
         UA_LDEBUG(@"Mark as read failed for message %@ with HTTP status: %ld", self.messageID, (long)request.response.statusCode);
         strongInbox.isBatchUpdating = NO;

         [strongInbox notifyObservers:@selector(singleMessageMarkAsReadFailed:) withObject:self];

         if (failureBlock && !isCallbackCancelled) {
             failureBlock(self);
         }
     }];

    return disposable;
}

- (UADisposable *)markAsReadWithDelegate:(id<UAInboxMessageListDelegate>)delegate {
    __weak id<UAInboxMessageListDelegate> weakDelegate = delegate;

    return [self markAsReadWithSuccessBlock:^(UAInboxMessage *message){
        id<UAInboxMessageListDelegate> strongDelegate = weakDelegate;
        if ([strongDelegate respondsToSelector:@selector(singleMessageMarkAsReadFinished:)]) {
            [strongDelegate singleMessageMarkAsReadFinished:message];
        }
    } withFailureBlock: ^(UAInboxMessage *message){
        id<UAInboxMessageListDelegate> strongDelegate = weakDelegate;
        if ([strongDelegate respondsToSelector:@selector(singleMessageMarkAsReadFailed:)]) {
            [strongDelegate singleMessageMarkAsReadFailed:message];
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

- (BOOL)markAsRead {
    //the return value should be YES if a request was sent or if we're already marked read.
    return [self markAsReadWithSuccessBlock:nil withFailureBlock:nil] || !self.unread;
}

- (void)setMessageID:(NSString *)messageID {
    _messageID = messageID;
    if (!self.data.isGone) {
        self.data.messageID = messageID;
    }
}

- (void)setMessageBodyURL:(NSURL *)messageBodyURL {
    _messageBodyURL = messageBodyURL;
    if (!self.data.isGone) {
        self.data.messageBodyURL = messageBodyURL;
    }
}

- (void)setMessageURL:(NSURL *)messageURL {
    _messageURL = messageURL;
    if (!self.data.isGone) {
        self.data.messageURL = messageURL;
    }
}

- (void)setContentType:(NSString *)contentType {
    _contentType = contentType;
    if (!self.data.isGone) {
        self.data.contentType = contentType;
    }
}

- (void)setUnread:(BOOL)unread {
    _unread = unread;
    if (!self.data.isGone) {
        self.data.unread = unread;
    }
}

- (void)setMessageSent:(NSDate *)messageSent {
    _messageSent = messageSent;
    if (!self.data.isGone) {
        self.data.messageSent = messageSent;
    }
}

- (void)setMessageExpiration:(NSDate *)messageExpiration {
    _messageExpiration = messageExpiration;
    if (!self.data.isGone) {
        self.data.messageExpiration = messageExpiration;
    }
}

- (void)setTitle:(NSString *)title {
    _title = title;
    if (!self.data.isGone) {
        self.data.title = title;
    }
}

- (void)setExtra:(NSDictionary *)extra {
    _extra = extra;
    if (!self.data.isGone) {
        self.data.extra = extra;
    }
}

- (void)setRawMessageObject:(NSDictionary *)rawMessageObject {
    _rawMessageObject = rawMessageObject;
    if (!self.data.isGone) {
        self.data.rawMessageObject = rawMessageObject;
    }
}

@end
