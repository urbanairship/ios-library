/*
 Copyright 2009-2010 Urban Airship Inc. All rights reserved.

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

@implementation UAInboxPushHandler

@synthesize viewingMessageID;
@synthesize hasLaunchMessage;

- (void)dealloc {
    RELEASE_SAFELY(viewingMessageID);
    [super dealloc];
}

+ (void) showMessageAfterMessageListLoaded {
    if ([UAInbox shared].activeInbox == nil) {
        [UAInbox setInbox:[UAInboxMessageList defaultInbox]];
	}
	
	[[UAInbox shared].activeInbox retrieveMessageList];
}

+ (void)handleNotification:(NSDictionary*)userInfo forInbox:(UAInboxMessageList*)inbox {

    UALOG(@"remote notification: %@", [userInfo description]);

    NSArray *mids = [userInfo objectForKey:@"_uamid"];
    if ([mids count] > 0) {
		[[UAInbox shared].pushHandler setViewingMessageID:[mids objectAtIndex:0]];
    }
	
    BOOL isActive = YES;
    
	IF_IOS4_OR_GREATER(
        isActive = [UIApplication sharedApplication].applicationState == UIApplicationStateActive;
    )

    if (isActive) {
        // only show alert view when the app is active
        // if it's running in background, apple will show a standard notification
        // alertview, so here we no need to show our alert
        NSString* message = [[userInfo objectForKey: @"aps"] objectForKey: @"alert"];
		
		id<UAInboxAlertProtocol> alertHandler = [[[UAInbox shared] uiClass] getAlertHandler];
        [alertHandler showNewMessageAlert:message];
		
    } else {
        // load message list and show the specified message
        [UAInboxPushHandler showMessageAfterMessageListLoaded];
    }
}

+ (void)handleLaunchOptions:(NSDictionary*)options {
    if(options == nil)
        return;

    UALOG(@"launch options: %@", options);

    NSString *mid = nil;
    NSArray *mids = [[options objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey] objectForKey:@"_uamid"];
    if (mids != nil && [mids count] > 0) {
        mid = [mids objectAtIndex:0];
    }

    if(mid != nil) {
        
		[[UAInbox shared].pushHandler setHasLaunchMessage:YES];
		[[UAInbox shared].pushHandler setViewingMessageID:mid];
			       
    }

}


- (id)init {
    if (self = [super init]) {
		hasLaunchMessage = NO;
	}
	return self;
}

@end