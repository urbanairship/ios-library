/*
 Copyright 2009-2015 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

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

#if __has_include("AirshipKit/AirshipKit.h")
#import <AirshipKit/AirshipKit.h>
#else
#import "AirshipLib.h"
#endif

#import "UACommon.h"

#import "InboxSampleViewController.h"
#import "InboxSampleAppDelegate.h"
#import "UAInboxMessageListController.h"
#import "UAInboxMessageViewController.h"
#import "InboxSampleUserInterface.h"
#import "InboxSampleModalUserInterface.h"
#import "InboxSamplePopoverUserInterface.h"
#import "InboxSampleNavigationUserInterface.h"

UA_SUPPRESS_UI_DEPRECATION_WARNINGS

typedef NS_ENUM(NSInteger, InboxStyle) {
    InboxStyleModal,
    InboxStyleNavigation
};

@interface InboxSampleViewController()
@property(nonatomic, assign) InboxStyle style;
@property(nonatomic, strong) UIPopoverController *popover;
@property(nonatomic, strong) id<InboxSampleUserInterface> userInterface;
@end

@implementation InboxSampleViewController
- (IBAction)mail:(id)sender {
    [self.userInterface showInbox];
}

- (BOOL)shouldUsePopover {
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && !self.runiPhoneTargetOniPad;
}

/*
 Builds a new instance of the message list controller, configuring buttons and closeBlock implemenations.
 */
- (UAInboxMessageListController *)buildMessageListController {
    UAInboxMessageListController *mlc = [[UAInboxMessageListController alloc] initWithNibName:@"UAInboxMessageListController"
                                                                                       bundle:[NSBundle bundleForClass:[UAInboxMessageListController class]]];
    mlc.title = @"Inbox";

    mlc.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                         target:self
                                                                                         action:@selector(inboxDone:)];

    // Optionally set a close block on the message list controller to be called when a message
    // is closed from within the rich content using 'UAirship.close()'. The default behavior
    // navigates back to the inbox message list.
    //
    // mlc.closeBlock = ^(BOOL animated) {
    //     if ([self.userInterface isVisible]) {
    //         [self.userInterface hideInbox];
    //     }
    // };

    return mlc;
}

- (void)inboxDone:(id)sender {
    if ([self.userInterface isVisible]) {
        [self.userInterface hideInbox];
    }
}

/*
 * Displays an inbox message.
 *
 * @param message The message to display.
 */
- (void)showInboxMessage:(UAInboxMessage *)message {
    if (![self.userInterface isVisible]) {
        if (self.useOverlay) {
            [UALandingPageOverlayController showMessage:message];
            return;
        } else {
            [self.userInterface showInbox];
        }
    }

    [self.userInterface.messageListController displayMessage:message];
}

/**
 * Displays the inbox.
 */
- (void)showInbox {
    if (![self.userInterface isVisible]) {
        [self.userInterface showInbox];
    }
}

- (void)setStyle:(enum InboxStyle)style {
    UAInboxMessageListController *mlc = [self buildMessageListController];
    switch (style) {
        case InboxStyleModal:
            self.userInterface = [[InboxSampleModalUserInterface alloc] initWithMessageListController:mlc];
            break;
        case InboxStyleNavigation:
            if ([self shouldUsePopover]) {
                self.userInterface = [[InboxSamplePopoverUserInterface alloc] initWithMessageListController:mlc
                                                                                        popoverSize:self.popoverSize];
            } else {
                self.userInterface = [[InboxSampleNavigationUserInterface alloc] initWithMessageListController:mlc];
            }
            break;
        default:
            break;
    }

    self.userInterface.parentController = self;
    _style = style;
}

- (IBAction)selectInboxStyle:(id)sender {
    
    NSString *popoverOrNav;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        popoverOrNav = @"Popover";
    }
    
    else {
        popoverOrNav = @"Navigation Controller";
    }
    
    
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Select Inbox Style" delegate:self 
                        cancelButtonTitle:@"Cancel" 
                   destructiveButtonTitle:nil 
                        otherButtonTitles:@"Modal", popoverOrNav, nil];
    
    [sheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    switch (buttonIndex) {
        case 0:
            self.style = InboxStyleModal;
            break;
        case 1:
            self.style = InboxStyleNavigation;
            break;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.runiPhoneTargetOniPad = NO;
    self.style = InboxStyleModal;

    self.version.text = [NSString stringWithFormat:@"UAInbox Version: %@", [UAirshipVersion get]];

    self.navigationItem.rightBarButtonItem  = [[UIBarButtonItem alloc] initWithTitle:@"Inbox"
                                                                               style:UIBarButtonItemStylePlain
                                                                              target:self action:@selector(mail:)];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


@end
