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

#import "UAirship.h"
#import "UAInbox.h"
#import "UAInboxAPIClient.h"
#import "UAInboxMessageList.h"
#import "UAInboxMessageListObserver.h"
#import "UAInboxDBManager.h"
#import "UAHTTPConnection.h"
#import "UAUtils.h"
#import "UAGlobal.h"

/*
 * Private methods
 */
@interface UAInboxMessage()

@property(nonatomic, retain) UAInboxAPIClient *client;

@end

/*
 * Implementation
 */
@implementation UAInboxMessage

- (id)initWithDict:(NSDictionary*)message inbox:(UAInboxMessageList *)i {
    self = [super init];
    if (self) {

        message = [message dictionaryWithValuesForKeys:[[message keysOfEntriesPassingTest:^BOOL(id key, id obj, BOOL *stop) {
                return ![obj isEqual:[NSNull null]];
            }] allObjects]];

        self.inbox = i;

        self.messageID = [message objectForKey: @"message_id"];
        self.contentType = [message objectForKey:@"content_type"];
        self.title = [message objectForKey: @"title"];
        self.extra = [message objectForKey: @"extra"];
        self.rawMessageObject = message;

        self.messageBodyURL = [NSURL URLWithString: [message objectForKey: @"message_body_url"]];
        self.messageURL = [NSURL URLWithString: [message objectForKey: @"message_url"]];

        self.unread = [[message objectForKey: @"unread"] intValue] ? YES : NO;

        NSString *dateString = [message objectForKey: @"message_sent"];
        self.messageSent = [[UAUtils ISODateFormatterUTC] dateFromString:dateString];

        self.client = [[[UAInboxAPIClient alloc] init] autorelease];
    }

    return self;
}

- (void)dealloc {
    self.messageID = nil;
    self.messageBodyURL = nil;
    self.messageURL = nil;
    self.contentType = nil;
    self.messageSent = nil;
    self.title = nil;
    self.extra = nil;
    self.rawMessageObject = nil;
    self.client = nil;
    [super dealloc];
}


#pragma mark -
#pragma mark NSObject methods

// NSObject override
- (BOOL)isEqual:(id)anObject {
    if (self == anObject) {
        return YES;
    }

    if (anObject == nil || ![anObject isKindOfClass:[UAInboxMessage class]]) {
        return NO;
    }

    UAInboxMessage *other = (UAInboxMessage *)anObject;
    return [self.messageID isEqualToString:other.messageID];
}

// NSObject override
- (NSUInteger)hash {
    return [self.messageID hash];
}

// NSObject override
- (NSString *)description {
    return [NSString stringWithFormat: @"%@ - %@", self.messageID, self.title];
}

#pragma mark -
#pragma mark Mark As Read Delegate Methods

- (BOOL)markAsRead {
    
    if (!self.unread) {
        return YES;
    }
    
    if (self.inbox.isBatchUpdating) {
        return NO;
    }
    
    self.inbox.isBatchUpdating = YES;

    [self.client
     markMessageRead:self onSuccess:^{
         if (self.unread) {
             self.inbox.unreadCount = self.inbox.unreadCount - 1;
             self.unread = NO;
             [[UAInboxDBManager shared] updateMessageAsRead:self];
         }

         self.inbox.isBatchUpdating = NO;
         [self.inbox notifyObservers:@selector(singleMessageMarkAsReadFinished:) withObject:self];

     }onFailure:^(UAHTTPRequest *request){
         UA_LDEBUG(@"Mark as read failed for message %@ with HTTP status: %ld", self.messageID, (long)request.response.statusCode);
         self.inbox.isBatchUpdating = NO;
         [self.inbox notifyObservers:@selector(singleMessageMarkAsReadFailed:) withObject:self];
     }];

    return YES;
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

@end
