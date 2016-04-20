/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

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

#import "UADefaultMessageCenter.h"
#import "UAirship.h"
#import "UAInbox.h"
#import "UAInboxMessage.h"
#import "UAUtils.h"
#import "UAMessageCenterLocalization.h"
#import "UADefaultMessageCenterListViewController.h"
#import "UADefaultMessageCenterMessageViewController.h"
#import "UADefaultMessageCenterSplitViewController.h"
#import "UADefaultMessageCenterStyle.h"
#import "UAConfig.h"

@interface UADefaultMessageCenter()
@property(nonatomic, strong) UADefaultMessageCenterSplitViewController *splitViewController;
@end

@implementation UADefaultMessageCenter

- (instancetype)init {
    self = [super init];
    if (self) {
        self.title = UAMessageCenterLocalizedString(@"ua_message_center_title");
    }
    return self;
}

+ (instancetype)messageCenterWithConfig:(UAConfig *)config {
    UADefaultMessageCenter *center = [[UADefaultMessageCenter alloc] init];
    center.style = [UADefaultMessageCenterStyle styleWithContentsOfFile:config.messageCenterStyleConfig];
    return center;
}

- (void)display:(BOOL)animated {
    if (!self.splitViewController) {

        self.splitViewController = [[UADefaultMessageCenterSplitViewController alloc] initWithNibName:nil bundle:nil];
        self.splitViewController.filter = self.filter;

        UADefaultMessageCenterListViewController *lvc = self.splitViewController.listViewController;

        lvc.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                             target:self
                                                                                             action:@selector(dismiss)];

        self.splitViewController.style = self.style;
        self.splitViewController.title = self.title;

        self.splitViewController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;

        [[UAUtils topController] presentViewController:self.splitViewController animated:animated completion:nil];
    }
}

- (void)display {
    [self display:YES];
}

- (void)displayMessage:(UAInboxMessage *)message animated:(BOOL)animated {
    [self display:animated];
    [self.splitViewController.listViewController displayMessage:message];
}

- (void)displayMessage:(UAInboxMessage *)message {
    [self displayMessage:message animated:NO];
}

- (void)dismiss:(BOOL)animated {
    [self.splitViewController.presentingViewController dismissViewControllerAnimated:animated completion:nil];
    self.splitViewController = nil;
}

- (void)dismiss {
    [self dismiss:YES];
}

@end
