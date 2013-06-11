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

#import "UAInboxMessage.h"

#import "UAirship.h"
#import "UAInbox.h"
#import "UAInboxMessageList.h"
#import "UAInboxDBManager.h"
#import "UAHTTPConnection.h"
#import "UAUtils.h"
#import "UAGlobal.h"

/*
 * Private methods
 */
@interface UAInboxMessage()

- (void)requestWentWrong:(UAHTTPRequest *)request;
- (void)markAsReadFailed:(UAHTTPRequest *)request;

@property(nonatomic, retain) UAInboxClient *client;

@end

/*
 * Implementation
 */
@implementation UAInboxMessage

@synthesize messageID;
@synthesize messageBodyURL;
@synthesize messageURL;
@synthesize contentType;
@synthesize unread;
@synthesize messageSent;
@synthesize title;
@synthesize extra;
@synthesize inbox; //TODO: this could be removed and replaced with a singleton reference

- (id)initWithDict:(NSDictionary*)message inbox:(UAInboxMessageList *)i {
    if (self = [super init]) {
        self.messageID = [message objectForKey: @"message_id"];
        self.inbox = i;
        self.messageBodyURL = [NSURL URLWithString: [message objectForKey: @"message_body_url"]];
        self.messageURL = [NSURL URLWithString: [message objectForKey: @"message_url"]];
        self.contentType = [message objectForKey:@"content_type"];
        self.unread = NO;
        if([message objectForKey: @"unread"] != [NSNull null] && [[message objectForKey: @"unread"] intValue] != 0) {
            self.unread = YES;
        }
        NSString *dateString = [message objectForKey: @"message_sent"];
        NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
		NSLocale *enUSPOSIXLocale = [[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease];
		[dateFormatter setLocale:enUSPOSIXLocale];
        [dateFormatter setTimeStyle:NSDateFormatterFullStyle];
        [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
		[dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
        self.messageSent = [dateFormatter dateFromString:dateString];
        [dateFormatter release];

        self.title = [message objectForKey: @"title"];
        self.extra = [message objectForKey: @"extra"];

        self.client = [[[UAInboxClient alloc] init] autorelease];
    }

    return self;
}

- (void)dealloc {
    RELEASE_SAFELY(messageID);
    RELEASE_SAFELY(messageBodyURL);
    RELEASE_SAFELY(messageURL);
    RELEASE_SAFELY(contentType);
    RELEASE_SAFELY(messageSent);
    RELEASE_SAFELY(title);
    RELEASE_SAFELY(extra);
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
    return [messageID hash];
}

// NSObject override
- (NSString*)description {
    return [NSString stringWithFormat: @"%@ - %@", messageID, title];
}

#pragma mark -
#pragma mark Mark As Read Delegate Methods

- (void)requestWentWrong:(UAHTTPRequest *)request {
    NSError *error = [request error];
    UALOG(@"Connection ERROR: NSError query result: %@ for URL: %@",
          error, [request.url absoluteString]);
    inbox.isBatchUpdating = NO;
}

- (BOOL)markAsRead {
    
    if (!unread) {
        return YES;
    }
    
    if (inbox.isBatchUpdating) {
        return NO;
    }
    
    inbox.isBatchUpdating = YES;

    [self.client
     markMessageRead:self onSuccess:^{
         if (self.unread) {
             [inbox setUnreadCount:(inbox.unreadCount - 1)];
             self.unread = NO;
             [[UAInboxDBManager shared] updateMessageAsRead:self];
         }

         inbox.isBatchUpdating = NO;
         [inbox notifyObservers:@selector(singleMessageMarkAsReadFinished:) withObject:self];

     }onFailure:^(UAHTTPRequest *request){
         [self markAsReadFailed:request];
     }];

    return YES;
}

- (void)markAsReadFailed:(UAHTTPRequest *)request {
    [self requestWentWrong:request];
    [inbox notifyObservers:@selector(singleMessageMarkAsReadFailed:) withObject:self];
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
