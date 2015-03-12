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

#import "InboxSamplePopoverUserInterface.h"

@interface InboxSamplePopoverUserInterface ()
@property(nonatomic, strong) UINavigationController *navigationController;
@property(nonatomic, strong) UIPopoverController *popoverController;
@end


@implementation InboxSamplePopoverUserInterface

- (instancetype)initWithMessageListController:(UAInboxMessageListController *)controller popoverSize:(CGSize)size {
    self = [super init];
    if (self) {
#if (__IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_7_0)
        controller.preferredContentSize = size;
#else
        controller.contentSizeForViewInPopover = size;
#endif
        self.popoverSize = size;
        self.messageListController = controller;
    }
    return self;
}

- (void)setMessageListController:(UAInboxMessageListController *)messageListController {

    self.navigationController = [[UINavigationController alloc] initWithRootViewController:messageListController];

    self.popoverController = [[UIPopoverController alloc] initWithContentViewController:self.navigationController];
    self.popoverController.popoverContentSize = self.popoverSize;
    self.popoverController.delegate = self;

    _messageListController = messageListController;
}

- (BOOL)isVisible {
    return self.popoverController.isPopoverVisible;
}

- (void)showInbox {
    [self.popoverController presentPopoverFromBarButtonItem:self.parentController.navigationItem.rightBarButtonItem
                                   permittedArrowDirections:UIPopoverArrowDirectionAny
                                                   animated:YES];
}

- (void)hideInbox {
    [self.navigationController popToRootViewControllerAnimated:NO];
    [self.popoverController dismissPopoverAnimated:YES];
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)dismissedPopoverController {
    [self hideInbox];
}

@end
