/*
Copyright 2009-2013 Urban Airship Inc. All rights reserved.

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

#import "UAirship.h"
#import "UAInbox.h"
#import "UAInboxMessageList.h"
#import "UAInboxMessageListObserver.h"
#import "UAInboxDBManager.h"
#import "UAHTTPConnection.h"
#import "UAUtils.h"
#import "UAGlobal.h"

/*
 * Implementation
 */
@implementation UAInboxMessage

@dynamic title;
@dynamic messageBodyURL;
@dynamic messageSent;
@dynamic messageExpiration;
@dynamic unread;
@dynamic messageURL;
@dynamic messageID;
@dynamic extra;
@dynamic rawMessageObject;

@synthesize inbox;
@synthesize contentType;
@synthesize client;

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

    if (!self.unread || self.inbox.isBatchUpdating) {
        return nil;
    }

    self.inbox.isBatchUpdating = YES;

    __block BOOL isCallbackCancelled = NO;
    UADisposable *disposable = [UADisposable disposableWithBlock:^{
        isCallbackCancelled = YES;
    }];

    [self.client
     markMessageRead:self onSuccess:^{
         if (self.unread) {
             self.inbox.unreadCount = self.inbox.unreadCount - 1;
             self.unread = NO;
             [[UAInboxDBManager shared] saveContext];
         }

         self.inbox.isBatchUpdating = NO;

         [self.inbox notifyObservers:@selector(singleMessageMarkAsReadFinished:) withObject:self];

         if (successBlock && !isCallbackCancelled) {
             successBlock(self);
         }
     } onFailure:^(UAHTTPRequest *request){
         UA_LDEBUG(@"Mark as read failed for message %@ with HTTP status: %ld", self.messageID, (long)request.response.statusCode);
         self.inbox.isBatchUpdating = NO;

         [self.inbox notifyObservers:@selector(singleMessageMarkAsReadFailed:) withObject:self];

         if (failureBlock && !isCallbackCancelled) {
             failureBlock(self);
         }
     }];

    return disposable;
}

- (UADisposable *)markAsReadWithDelegate:(id<UAInboxMessageListDelegate>)delegate {
    __weak id<UAInboxMessageListDelegate> weakDelegate = delegate;

    return [self markAsReadWithSuccessBlock:^(UAInboxMessage *message){
        if ([weakDelegate respondsToSelector:@selector(singleMessageMarkAsReadFinished:)]) {
            [weakDelegate singleMessageMarkAsReadFinished:message];
        }
    } withFailureBlock: ^(UAInboxMessage *message){
        if ([weakDelegate respondsToSelector:@selector(singleMessageMarkAsReadFailed:)]) {
            [weakDelegate singleMessageMarkAsReadFailed:message];
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

#pragma mark -
#pragma mark JavaScript Delegate

+ (void)performJSDelegate:(UIWebView*)webView url:(NSURL *)url {
    
    NSString *urlPath = [url path];
    if ([urlPath hasPrefix:@"/"]) {
        urlPath = [urlPath substringFromIndex:1]; //trim the leading slash
    }

    // Put the arguments into an array
    // NOTE: we special case an empty array as componentsSeparatedByString
    // returns an array with a copy of the input in the first position when passed
    // a string without any delimiters
    NSArray* arguments;
    if ([urlPath length] > 0) {
        arguments = [urlPath componentsSeparatedByString:@"/"];
    } else {
        arguments = [NSArray array];//empty
    }
    
    // Dictionary of options - primitive parsing, so external docs should mention the limitations
    NSString *urlQuery = [url query];
    NSMutableDictionary* options = [NSMutableDictionary dictionary];
    NSArray * queries = [urlQuery componentsSeparatedByString:@"&"];

    for (int i = 0; i < [queries count]; i++) {
        NSArray *optionPair = [[queries objectAtIndex:i] componentsSeparatedByString:@"="];
        NSString *key = [optionPair objectAtIndex:0];
        NSString *object = [optionPair objectAtIndex:1];
        [options setObject:object forKey:key];
    }

    SEL selector = NSSelectorFromString(@"callbackArguments:withOptions:");
    if ([[UAInbox shared].jsDelegate respondsToSelector:selector]) {
        NSString *script = [[UAInbox shared].jsDelegate callbackArguments:arguments withOptions:options];
        if (script) {
            [webView stringByEvaluatingJavaScriptFromString:script];
        }
    }
}

-(UAInboxAPIClient *)client {
    if (!client) {
       client = [[UAInboxAPIClient alloc] init];
    }

    return client;
}

@end
