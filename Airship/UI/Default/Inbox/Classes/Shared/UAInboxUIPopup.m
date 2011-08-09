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

#import "UAInboxUIPopup.h"
#import "UAInboxMessageListController.h"
#import "UAInboxMessageViewController.h"
#import "UAPopupWindow.h"

#import "UAInboxMessageList.h"
#import "UAInboxPushHandler.h"

@implementation UAInboxUIPopup

SINGLETON_IMPLEMENTATION(UAInboxUIPopup)

+ (void)displayInbox:(UIViewController *)viewController animated:(BOOL)animated {
	
    if ([viewController isKindOfClass:[UINavigationController class]]) {
        [(UINavigationController *)viewController popToRootViewControllerAnimated:NO];
    }
    
	[UAInboxUIPopup shared].isVisible = YES;
    
    UALOG(@"present modal");
    [viewController presentModalViewController:[UAInboxUIPopup shared].rootViewController animated:animated];
} 

+ (void)displayMessage:(UIViewController *)viewController message:(NSString *)messageID {
    
    //if the inbox is not displaying, show the message in an overlay window
    if(![UAInboxUI shared].isVisible) {
        [UAPopupWindow showWindowWithMessageID:messageID];
    }
    
    else {
        // For iPhone
        UINavigationController *navController = (UINavigationController *)[UAInboxUIPopup shared].rootViewController;
        UAInboxMessageViewController *mvc;
        
        //if a message view is displaying, just load the new message
        if ([navController.topViewController class] == [UAInboxMessageViewController class]) {
            mvc = (UAInboxMessageViewController *) navController.topViewController;
            [mvc loadMessageForID:messageID];
        } 
        
        //otherwise, push over a new message view
        else {
            mvc = [[[UAInboxMessageViewController alloc] initWithNibName:@"UAInboxMessageViewController" bundle:nil] autorelease];
            [mvc loadMessageForID:messageID];
            [navController pushViewController:mvc animated:YES];
        }
    }
}

+ (void)newMessageArrived:(NSDictionary *)message {
    
    NSString* alertText = [[message objectForKey: @"aps"] objectForKey: @"alert"];
    
    [[UAInboxUIPopup shared].alertHandler showNewMessageAlert:alertText];
}

+ (void)quitInbox {
    [[UAInboxUIPopup shared] quitInbox];
}

+ (void)loadLaunchMessage {
    	
	// if pushhandler has a messageID load it
    UAInboxPushHandler *pushHandler = [UAInbox shared].pushHandler;
    
    UAInboxMessage *msg = [[UAInbox shared].messageList messageForID:[pushHandler viewingMessageID]];
    
    if (!msg) {
        return;
    }
            
    [UAInboxUIPopup displayMessage:nil message:[[UAInbox shared].pushHandler viewingMessageID]];
    
    [[UAInbox shared].pushHandler setViewingMessageID:nil];
    [[UAInbox shared].pushHandler setHasLaunchMessage:NO];    
}

@end
