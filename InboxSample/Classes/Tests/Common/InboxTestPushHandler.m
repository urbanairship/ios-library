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
#import "InboxTestPushHandler.h"
#import "UA_SBJSON.h"
#import "ASIHTTPRequest+UATest.h"
#import "UAirship.h"
#import "UAInboxMessageList.h"

@implementation InboxTestPushHandler

SINGLETON_IMPLEMENTATION(InboxTestPushHandler);

- (id)init {
    if (self = [super init]){
        callbackDelegates = [[NSMutableDictionary alloc] init];
        NSString *path = [[NSBundle mainBundle]
                          pathForResource:@"AirshipConfig" ofType:@"plist"];
        if (path != nil){
            NSMutableDictionary *config = [[[NSMutableDictionary alloc] initWithContentsOfFile:path] autorelease];

            APP_MASTER_SECRET = [[config objectForKey:@"APP_MASTER_SECRET"] retain];
        }
    }
    return self;
}

- (void)handleNotification:(NSDictionary*)userInfo {
    UALOG(@"remote notification for test: %@", [userInfo description]);


    // Get the rich push ID, which can be sent as a one-element array or a string
    NSString *richPushId = nil;
    NSObject *richPushValue = [[options objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey] objectForKey:@"_uamid"];
    if ([richPushValue isKindOfClass:[NSArray class]]) {
        NSArray *richPushIds = (NSArray *)richPushValue;
        if (richPushIds.count > 0) {
            richPushId = [richPushIds objectAtIndex:0];
        }
    } else if ([richPushValue isKindOfClass:[NSString class]]) {
        richPushId = (NSString *)richPushValue;
    }
    
    if (richPushId) {
        UALOG(@"Retrieving for message: %@", mid);
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@%@%@/", [UAirship shared].server, @"/api/user/", [UAUser defaultUser].username, @"/messages/message/", mid]];
        UA_ASIHTTPRequest *msgReq = [[UA_ASIHTTPRequest alloc] initWithURL:url];
        UALOG(@"URL = %@", msgReq.url);
        msgReq.username = [UAUser defaultUser].username;
        msgReq.password = [UAUser defaultUser].password;
        [msgReq startSynchronous];

        UA_SBJsonParser *parser = [UA_SBJsonParser new];
        NSDictionary* jsonResponse = [parser objectWithString: [msgReq responseString]];
        UALOG(@"Response status code/desc = %d %@", msgReq.responseStatusCode, msgReq.responseStatusMessage);
        UALOG(@"Response string: %@", [msgReq responseString]);
        [parser release];
        [msgReq release];

        if (jsonResponse){
            UALOG(@"Getting info for callback.");
            NSDictionary* info = [jsonResponse objectForKey:@"extra"];
            NSString *selectorName = [info objectForKey:@"selector"];
            NSString *delegateName = [info objectForKey:@"delegate"];
            SEL selector = NSSelectorFromString(selectorName);

            UAInboxMessage *tmp = [[[UAInboxMessage alloc] init] autorelease];
            tmp.messageID = [jsonResponse objectForKey:@"message_id"];
            tmp.messageBodyURL = [NSURL URLWithString:[jsonResponse objectForKey:@"message_body_url"]];
            tmp.messageURL = url;
            tmp.unread = NO;
            if([jsonResponse objectForKey:@"unread"] != [NSNull null] && [[jsonResponse objectForKey:@"unread"] intValue] != 0) {
                tmp.unread = YES;
            }
            NSString* dateString = [jsonResponse objectForKey:@"message_sent"];
            NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setTimeStyle:NSDateFormatterFullStyle];
            [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
            tmp.messageSent = [dateFormatter dateFromString:dateString];
            [dateFormatter release];

            tmp.title = [jsonResponse objectForKey:@"title"];

            id delegate = [callbackDelegates objectForKey:delegateName];
            if (delegate == nil){
                GHFail(@"Callback delegate for push notification is nil");
            }
            if ([delegate respondsToSelector:selector]){
                UALOG(@"Performing selector");
                [delegate performSelector:selector withObject:tmp];
            } else {
                GHFail(@"Delegate does not respond to specified selector");
            }
        } else {
            GHFail(@"Message detail response is nil");
        }

    }
}

- (void)pushMessageData:(NSDictionary *)messageLoad delegate:(id)delegate selector:(SEL)selector{
    GHAssertNotNil(APP_MASTER_SECRET, @"No AirshipConfig.plist file, or no APP_MASTER_SECRET setting in file.  Cannot send push notifications.");

    [callbackDelegates setObject:delegate forKey:NSStringFromClass([delegate class])];

    NSMutableDictionary *data = [NSMutableDictionary dictionaryWithDictionary:messageLoad];

    NSDictionary *ex = [data objectForKey:@"extra"];
    NSMutableDictionary *extra = nil;
    if (ex != nil){
        extra = [NSMutableDictionary dictionaryWithDictionary:ex];
    } else {
        extra = [NSMutableDictionary dictionary];
    }

    [extra setObject:NSStringFromClass([delegate class]) forKey:@"delegate"];
    [extra setObject:NSStringFromSelector(selector) forKey:@"selector"];

    [data setObject:extra forKey:@"extra"];

    UA_SBJsonWriter *writer = [UA_SBJsonWriter new];
    NSString* body = [writer stringWithObject:data];
    UALOG(@"JSON body for sending push: %@", body);
    [writer release];

    NSString *urlString = [NSString stringWithFormat:@"%@%@",
                           [UAirship shared].server,
                           @"/api/airmail/send/"];
    NSURL *url = [NSURL URLWithString:urlString];

    UA_ASIHTTPRequest *request = [[[UA_ASIHTTPRequest alloc] initWithURL:url] autorelease];

    [request setRequestMethod:@"POST"];

    request.username = [UAirship shared].appId;
    request.password = APP_MASTER_SECRET;

    request.delegate = self;
    request.timeOutSeconds = 60;
    [request setDidFailSelector:@selector(messageRequestWentWrong:)];
    [request setDidFinishSelector:@selector(requestOK:)];

    [request addRequestHeader:@"Content-Type" value:@"application/json"];
    [request appendPostData:[body dataUsingEncoding:NSUTF8StringEncoding]];

    [request startAsynchronous];
}


- (void)messageRequestWentWrong:(UA_ASIHTTPRequest *)request {
    NSError *error = [request error];
    UALOG(@"Connection ERROR: NSError query result: %@, for URL: %@, with response: %d",
          error, [request.url absoluteString], request.responseStatusCode);
    GHFail(@"Message request went wrong with error: %@, for URL: %@, with response: %d %@",
           error, [request.url absoluteString], request.responseStatusCode, request.responseStatusMessage);
}

- (void)requestOK:(UA_ASIHTTPRequest*)request {
    UALOG(@"Response = %d %@", request.responseStatusCode, request.responseStatusMessage);
    if (request.responseStatusCode != 200) {
        UALOG(@"Server error during sending push notification.");
        GHFail(@"Message request went wrong for URL: %@ with response: %d %@",
               [request.url absoluteString], request.responseStatusCode, request.responseStatusMessage);
    }
}


- (void)dealloc {
    RELEASE_SAFELY(callbackDelegates);
    RELEASE_SAFELY(APP_MASTER_SECRET);
    [super dealloc];
}

@end
