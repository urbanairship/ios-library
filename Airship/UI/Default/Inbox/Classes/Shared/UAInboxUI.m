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

#import "UAInboxUI.h"

@implementation UAInboxUI
@synthesize rootViewController, messageViewController, inboxParentController, messageListController, localizationBundle, messageListTitle;
@synthesize isVisible, uaWindow, isiPad;

SINGLETON_IMPLEMENTATION(UAInboxUI)

static BOOL runiPhoneTargetOniPad = NO;

+ (void)setRuniPhoneTargetOniPad:(BOOL)value {
    runiPhoneTargetOniPad = value;
}

- (void)dealloc {
    RELEASE_SAFELY(rootViewController);
    RELEASE_SAFELY(messageViewController);
    RELEASE_SAFELY(messageListController);
    RELEASE_SAFELY(localizationBundle);
    RELEASE_SAFELY(messageListTitle);
	RELEASE_SAFELY(alertHandler);
	RELEASE_SAFELY(inboxParentController);
    [super dealloc];
}

- (id)init {
    if (self = [super init]) {
		
        NSString* path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"UAInboxLocalization.bundle"];
        self.localizationBundle = [NSBundle bundleWithPath:path];

        // Dynamically create root view controller for iPad
        NSString *deviceType = [UIDevice currentDevice].model;
		
        if ([deviceType hasPrefix:@"iPad"] && !runiPhoneTargetOniPad) {
            
			self.isiPad = YES;

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 30200
            self.messageListController = [[[UAInboxMessageListControllerPad alloc] initWithNibName:
                                 @"UAInboxMessageListController_Pad" bundle: nil] autorelease];
            self.messageViewController = [[[UAInboxMessageViewControllerPad alloc] initWithNibName:
                                 @"UAInboxMessageViewController_Pad" bundle: nil] autorelease];

            UINavigationController *navController = [[[UINavigationController alloc]
                                                      initWithRootViewController:messageListController] autorelease];
            self.rootViewController = [[[NSClassFromString(@"UISplitViewController") alloc] init] autorelease];
            [rootViewController performSelector:@selector(setViewControllers:)
                                     withObject:[NSArray arrayWithObjects:navController, messageViewController, nil]];
            [rootViewController performSelector:@selector(setDelegate:) withObject:messageListController];
#endif

        } else {
            self.isiPad = NO;
            self.messageListController = [[[UAInboxMessageListController alloc] initWithNibName:
                                 @"UAInboxMessageListController" bundle: nil] autorelease];
            self.messageViewController = [[[UAInboxMessageViewController alloc] initWithNibName:
                                 @"UAInboxMessageViewController" bundle: nil] autorelease];
            self.rootViewController = [[[UAInboxNavigationController alloc] initWithRootViewController:messageListController] autorelease];
        }

        [[UAInbox shared].activeInbox addObserver:messageListController];
        [[UAInbox shared].activeInbox addObserver:messageViewController];
		[[UAInbox shared].activeInbox addObserver:self];
		
		alertHandler = [[UAInboxAlertHandler alloc] init];
		
        self.messageListTitle = @"Inbox";
        self.isVisible = NO;
		
    }
    return self;
}

+ (void)displayInbox:(UIViewController *)viewController animated:(BOOL)animated {
	
    if ([viewController isKindOfClass:[UINavigationController class]]) {
        [(UINavigationController *)viewController popToRootViewControllerAnimated:NO];
    }

	[UAInboxUI shared].isVisible = YES;

	if ([UAInboxUI shared].isiPad) {
        if ([UAInboxUI shared].uaWindow == nil) {
            [UAInboxUI shared].uaWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
			
            CGRect frame = viewController.view.frame;
			UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
            
			if (UIInterfaceOrientationIsLandscape(orientation)) {
                viewController.view.frame = CGRectMake(frame.origin.x, frame.origin.y, frame.size.height, frame.size.width);
            }
            
			[[UAInboxUI shared].uaWindow addSubview:[UAInboxUI shared].rootViewController.view];
			
        }
		
        [[UAInboxUI shared].uaWindow makeKeyAndVisible];
		
    } else {
		UALOG(@"present modal");
        [viewController presentModalViewController:[UAInboxUI shared].rootViewController animated:animated];
    }
}

+ (void)displayMessage:(UIViewController *)viewController message:(NSString *)messageID {
	
    if(![UAInboxUI shared].isVisible) {
        UALOG(@"UI needs to be brought up!");
		// We're not inside the modal/navigationcontroller setup so lets start with the parent
		[UAInboxUI displayInbox:[UAInboxUI shared].inboxParentController animated:NO]; // BUG?
	}
	
    // If the message view is already open, just load the first message.
    if ([viewController isKindOfClass:[UINavigationController class]]) {
		
        // For iPhone
        UINavigationController *navController = (UINavigationController *)viewController;
        
		if ([navController.topViewController class] == [UAInboxMessageViewController class]) {
            [[UAInboxUI shared].messageViewController loadMessageForID:messageID];
        } else {
			
			// if ([navController.topViewController class] == [InboxMessageListController class])
			
            [[UAInboxUI shared].messageViewController loadMessageForID:messageID];
            [navController pushViewController:[UAInboxUI shared].messageViewController animated:YES];
        }
    } else {
        // For iPad
        [[UAInboxUI shared].messageViewController loadMessageForID:messageID];
    }
}

+ (void)quitInbox {
    [[UAInboxUI shared] quitInbox:NORMAL_QUIT];
}

- (void)quitInbox:(QuitReason)reason {
    if (reason == DEVICE_TOKEN_ERROR) {
        UALOG(@"Inbox not initialized. Waiting for Device Token.");
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:UA_INBOX_TR(@"UA_Inbox_Not_Ready_Title")
                                                        message:UA_INBOX_TR(@"UA_Error_Get_Device_Token")
                                                       delegate:nil
                                              cancelButtonTitle:UA_INBOX_TR(@"UA_OK")
                                              otherButtonTitles:nil];
        [alert show];
        [alert release];
    } else if (reason == USER_ERROR) {
        UALOG(@"Inbox not initialized. Waiting for Device Token.");
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:UA_INBOX_TR(@"UA_Inbox_Not_Ready_Title")
                                                        message:UA_INBOX_TR(@"UA_Inbox_Not_Ready")
                                                       delegate:nil
                                              cancelButtonTitle:UA_INBOX_TR(@"UA_OK")
                                              otherButtonTitles:nil];
        [alert show];
        [alert release];
    } else {
        NSLog(@"reason=%d", reason);
    }

    if ([rootViewController isKindOfClass:[UINavigationController class]]) {
        [(UINavigationController *)rootViewController popToRootViewControllerAnimated:NO];
    }
	
    self.isVisible = NO;

	if (self.isiPad) {
        self.uaWindow.hidden = YES;
    } else {
        UIViewController *con = self.rootViewController.parentViewController;
        [con dismissModalViewControllerAnimated:YES];
		
        // BUG: Workaround. ModalViewController does not handle resizing correctly if
        // dismissed in landscape when status bar is visible
        if (![UIApplication sharedApplication].statusBarHidden)
            con.view.frame = UAFrameForCurrentOrientation(con.view.frame);
    }
}

// handle both in app notification and launching notification
- (void)messageListLoaded {
	[UAInboxUI loadLaunchMessage];
}


+ (void) loadLaunchMessage {
	
	// if pushhandler has a messageID load it
	if([[UAInbox shared].pushHandler viewingMessageID] != nil) {

		UAInboxMessage *msg = [[UAInbox shared].activeInbox messageForID:[[UAInbox shared].pushHandler viewingMessageID]];
		if (msg == nil) {
			return;
		}
		
		[UAInboxUI displayMessage:[UAInboxUI shared].rootViewController message:[[UAInbox shared].pushHandler viewingMessageID]];
		
		[[UAInbox shared].pushHandler setViewingMessageID:nil];
		[[UAInbox shared].pushHandler setHasLaunchMessage:NO];
	}

}

+ (void)land {
    [[UAInbox shared].activeInbox removeObserver:[UAInboxUI shared].messageListController];
    [[UAInbox shared].activeInbox removeObserver:[UAInboxUI shared].messageViewController];
	[[UAInboxMessageList defaultInbox] removeObserver:self];
}

+ (id<UAInboxAlertProtocol>)getAlertHandler {
    UAInboxUI* ui = [UAInboxUI shared];
    return ui->alertHandler;
}

@end
