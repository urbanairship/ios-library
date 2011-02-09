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


#import "UAInboxPushHandler.h"
#import "UAInboxMessageList.h"
#import "UAInboxAlertProtocol.h"
#import "UAEvent.h"

@implementation UAInboxPushHandler

@synthesize viewingMessageID;
@synthesize hasLaunchMessage;

- (void)dealloc {
    RELEASE_SAFELY(viewingMessageID);
    [super dealloc];
}

+ (BOOL)isApplicationActive {
    BOOL isActive = YES;
	IF_IOS4_OR_GREATER(
					   isActive = [UIApplication sharedApplication].applicationState == UIApplicationStateActive;
					   )
    return isActive;
}

+ (void) showMessageAfterMessageListLoaded {
    if ([UAInbox shared].activeInbox == nil) {
        [UAInbox setInbox:[UAInboxMessageList defaultInbox]];
	}
	
	[[UAInbox shared].activeInbox retrieveMessageList];
}

+ (void)handleNotification:(NSDictionary*)userInfo forInbox:(UAInboxMessageList*)inbox {

    UALOG(@"remote notification: %@", [userInfo description]);

    // Get the rich push ID, which can be sent as a one-element array or a string
    NSString *richPushId = nil;
    NSObject *richPushValue = [userInfo objectForKey:@"_uamid"];
    if ([richPushValue isKindOfClass:[NSArray class]]) {
        NSArray *richPushIds = (NSArray *)richPushValue;
        if (richPushIds.count > 0) {
            richPushId = [richPushIds objectAtIndex:0];
        }
    } else if ([richPushValue isKindOfClass:[NSString class]]) {
        richPushId = (NSString *)richPushValue;
    }
    
    if (richPushId) {
        [[UAInbox shared].pushHandler setViewingMessageID:richPushId];
    }
	
	BOOL isActive = [self isApplicationActive];

    if (isActive) {
		
		// add push_received event
        [[UAirship shared].analytics addEvent:[UAEventPushReceived eventWithContext:userInfo]];
		
        // only show alert view when the app is active
        // if it's running in background, apple will show a standard notification
        // alertview, so here we no need to show our alert
        NSString* message = [[userInfo objectForKey: @"aps"] objectForKey: @"alert"];
		
		id<UAInboxAlertProtocol> alertHandler = [[[UAInbox shared] uiClass] getAlertHandler];
        [alertHandler showNewMessageAlert:message];
		
    } else {
		[[UAirship shared].analytics handleNotification:userInfo];
		
        // load message list and show the specified message
        [UAInboxPushHandler showMessageAfterMessageListLoaded];
    }
}

+ (void)handleLaunchOptions:(NSDictionary*)options {
    
    if (options == nil) {
        return;
    }

    UALOG(@"launch options: %@", options);

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
		[[UAInbox shared].pushHandler setHasLaunchMessage:YES];
		[[UAInbox shared].pushHandler setViewingMessageID:richPushId];
    }
    
}


- (id)init {
    if (self = [super init]) {
		hasLaunchMessage = NO;
	}
	return self;
}

@end