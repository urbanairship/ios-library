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

#import "UAInboxNavUI.h"
#import "UAInboxMessageListController.h"
#import "UAInboxMessageViewController.h"
#import "UAInboxMessageList.h"
#import "UAInboxPushHandler.h"

#import "UALandingPageOverlayController.h"
#import "UAUtils.h"

@interface UAInboxNavUI ()

@property (nonatomic, strong) UIViewController *rootViewController;
@property (nonatomic, assign) BOOL isVisible;
@property (nonatomic, strong) UAInboxMessageViewController *messageViewController;
@property (nonatomic, strong) UAInboxMessageListController *messageListController;
@property (nonatomic, strong) UAInboxAlertHandler *alertHandler;

@end

@implementation UAInboxNavUI

SINGLETON_IMPLEMENTATION(UAInboxNavUI)

static BOOL runiPhoneTargetOniPad = NO;

+ (void)setRuniPhoneTargetOniPad:(BOOL)value {
    runiPhoneTargetOniPad = value;
}


- (id)init {
    self = [super init];
    if (self) {
        NSString* path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"UAInboxLocalization.bundle"];
        self.localizationBundle = [NSBundle bundleWithPath:path];

        self.useOverlay = NO;
        self.isVisible = NO;

        self.alertHandler = [[UAInboxAlertHandler alloc] init];
        
        self.popoverSize = CGSizeMake(320, 1100);
    }
    
    return self;
}

- (void)createMessageListController {
    UAInboxMessageListController *mlc = [[UAInboxMessageListController alloc] initWithNibName:@"UAInboxMessageListController" bundle:nil];

    mlc.navigationItem.leftBarButtonItem =
    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(inboxDone:)];

    self.messageListController = mlc;
}

- (void)inboxDone:(id)sender {
    [self quitInbox:YES];
}

+ (void)displayInboxInViewController:(UIViewController *)parentViewController animated:(BOOL)animated {

    if ([self shared].isVisible) {
        //don't display twice
        return;
    }

    [[self shared] createMessageListController];

    if ([parentViewController isKindOfClass:[UINavigationController class]]) {
        [self shared].isVisible = YES;
        if (parentViewController) {
            [self shared].inboxParentController = parentViewController;
        }
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && !runiPhoneTargetOniPad) {
            [self shared].navigationController = [[UINavigationController alloc] initWithRootViewController:[self shared].messageListController];
            [self shared].popoverController = [[UIPopoverController alloc] initWithContentViewController:[self shared].navigationController];
            
            [self shared].popoverController.popoverContentSize = [self shared].popoverSize;
            [self shared].messageListController.contentSizeForViewInPopover = [self shared].popoverSize;
            
            [self shared].popoverController.delegate = [self shared];
            
            [[self shared].popoverController 
                presentPopoverFromBarButtonItem:[self shared].popoverButton
                       permittedArrowDirections:UIPopoverArrowDirectionAny
                                       animated:animated];
        } else {
            [self shared].navigationController = (UINavigationController *)parentViewController;
            [[self shared].navigationController pushViewController:[self shared].messageListController animated:animated];
        }
    } else {
        UALOG(@"Not a navigation controller");
    }

} 

+ (void)displayMessageWithID:(NSString *)messageID inViewController:(UIViewController *)parentViewController {

    if(![self shared].isVisible) {
        
        if ([self shared].useOverlay) {
            UAInboxMessage *message = [[UAInbox shared].messageList messageForID:messageID];
            NSURL *messageBodyURL = message.messageBodyURL;
            if (messageBodyURL) {
                [UALandingPageOverlayController showMessage:message];
            } else {
                UA_LDEBUG(@"Unable to retrieve message body URL");
            }
            return;
        }

        else {
            UALOG(@"UI needs to be brought up!");
            parentViewController = parentViewController?:[self shared].inboxParentController;
            [self displayInboxInViewController:parentViewController animated:NO];
        }
    }

    // Use the parent view controller if one is not specified.
    parentViewController = parentViewController ?: [self shared].inboxParentController;

    // If the message view is already open, just load the first message.
    if ([parentViewController isKindOfClass:[UINavigationController class]]) {

        // For iPhone
        UINavigationController *navController = (UINavigationController *)parentViewController;

        if ([navController.topViewController class] == [UAInboxMessageViewController class]) {
            [[self shared].messageViewController loadMessageForID:messageID];
        } else {

            [self shared].messageViewController = 
                [[UAInboxMessageViewController alloc] initWithNibName:@"UAInboxMessageViewController" bundle:nil];
            [self shared].messageViewController.closeBlock = ^(BOOL animated){
                [[self shared] quitInbox:animated];
            };

            [[self shared].messageViewController loadMessageForID:messageID];
            [navController pushViewController:[self shared].messageViewController animated:YES];
        }
    }
}

+ (void)quitInbox {
    [[self shared] quitInbox:YES];
}

- (void)quitInbox:(BOOL)animated {
    self.isVisible = NO;
    [self.navigationController popToRootViewControllerAnimated:animated];
    
    if (self.popoverController) {
        [self.popoverController dismissPopoverAnimated:animated];
        self.popoverController = nil;
    }

    self.messageListController = nil;
    self.messageViewController = nil;
}

+ (void)land {
    //do any necessary teardown here
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)dismissedPopoverController {
    if (self.popoverController == dismissedPopoverController) {
        [UAInbox quitInbox];
    }
}

- (void)richPushNotificationArrived:(NSDictionary *)message {
    //custom launch notification handling here
}

- (void)richPushMessageAvailable:(UAInboxMessage *)richPushMessage {
    NSString *alertText = richPushMessage.title;
    [self.alertHandler showNewMessageAlert:alertText withViewBlock:^{
        [self.class displayMessageWithID:richPushMessage.messageID inViewController:nil];
    }];
}

- (void)applicationLaunchedWithRichPushNotification:(NSDictionary *)notification {
    //custom launch notification handling here
}

- (void)launchRichPushMessageAvailable:(UAInboxMessage *)richPushMessage {
    [self.class displayMessageWithID:richPushMessage.messageID inViewController:nil];
}

@end
