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


#import "UAInboxPushHandler.h"
#import "UAirship.h"

#import "UAInbox.h"
#import "UAInboxMessageList.h"
#import "UAAnalytics.h"
#import "UAEvent.h"



@implementation UAInboxPushHandler

@synthesize viewingMessageID;
@synthesize delegate;
@synthesize hasLaunchMessage;

- (void)dealloc {
    RELEASE_SAFELY(viewingMessageID);
    RELEASE_SAFELY(delegate);
    [[[UAInbox shared] messageList] removeObserver:self];
    [super dealloc];
}

+ (BOOL)isApplicationActive {
    return ([UIApplication sharedApplication].applicationState == UIApplicationStateActive);
}


+ (void)handleNotification:(NSDictionary*)userInfo{

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
	
    // add push_received event, or handle appropriately
    [[UAirship shared].analytics handleNotification:userInfo];
    
    if (richPushId) {
        [UAInbox shared].pushHandler.viewingMessageID = richPushId;
       
        //if the app is in the foreground, let the UI class decide how it
        //wants to respond to the incoming push
        if ([self isApplicationActive]) {
            [[UAInbox shared].pushHandler.delegate newMessageArrived:userInfo];
        }
        
        //otherwise, load the message list
        else {
            //this will result in calling loadLaunchMessage on the UI class
            //once the request is complete
            [UAInbox shared].pushHandler.hasLaunchMessage = YES;
            
            [[UAInbox shared].messageList retrieveMessageList];
        }
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

- (void)messageListLoaded {
    
    //only take action is there's a new message
    if(viewingMessageID) {
        
        Class <UAInboxUIProtocol> uiClass  = [UAInbox shared].uiClass;
        
        //if the notification came in while the app was backgrounded, treat it as a launch message
        if (hasLaunchMessage) {
            [uiClass loadLaunchMessage];
        }
        
        //otherwise, have the UI class display it
        else {
            [uiClass displayMessage:nil message:viewingMessageID];
            [self setViewingMessageID:nil];
        }
    }
}


- (id)init {
    if (self = [super init]) {
		hasLaunchMessage = NO;
        [[[UAInbox shared] messageList] addObserver:self];
	}
	return self;
}

@end