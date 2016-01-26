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

#import "UADefaultMessageCenter.h"
#import "UAirship.h"
#import "UAInbox.h"
#import "UAInboxMessage.h"
#import "UAUtils.h"
#import "UAMessageCenterLocalization.h"
#import "UADefaultMessageCenterListViewController.h"
#import "UADefaultMessageCenterMessageViewController.h"
#import "UADefaultMessageCenterStyle.h"

@interface UADefaultMessageCenter()

@property(nonatomic, strong) UADefaultMessageCenterListViewController *listController;
@property(nonatomic, strong) UINavigationController *navigationController;

@end

@implementation UADefaultMessageCenter

- (instancetype)init {
    self = [super init];
    if (self) {
        self.title = UAMessageCenterLocalizedString(@"UA_Message_Center_Title");
    }
    return self;
}


- (void)display:(BOOL)animated {
    if (!self.listController) {
        NSBundle *airshipResources = [UAirship resources];

        UADefaultMessageCenterListViewController *lvc;
        lvc = [[UADefaultMessageCenterListViewController alloc] initWithNibName:@"UADefaultMessageCenterListViewController"
                                                                         bundle:airshipResources];
        lvc.title = self.title;
        lvc.style = self.style;
        lvc.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                             target:self
                                                                                             action:@selector(dismiss)];

        UADefaultMessageCenterMessageViewController *mvc;
        mvc = [[UADefaultMessageCenterMessageViewController alloc] initWithNibName:@"UADefaultMessageCenterMessageViewController"
                                                                            bundle:airshipResources];
        mvc.style = self.style;

        UINavigationController *listnav = [[UINavigationController alloc] initWithRootViewController:lvc];
        UINavigationController *messagenav = [[UINavigationController alloc] initWithRootViewController:mvc];

        if (self.style.navigationBarColor) {
            listnav.navigationBar.barTintColor = self.style.navigationBarColor;
            messagenav.navigationBar.barTintColor = self.style.navigationBarColor;
        }

        NSMutableDictionary *titleAttributes = [NSMutableDictionary dictionary];

        if (self.style.titleColor) {
            titleAttributes[UITextAttributeTextColor] = self.style.titleColor;
        }

        if (self.style.titleFont) {
            titleAttributes[UITextAttributeFont] = self.style.titleFont;
        }

        if (titleAttributes.count) {
            listnav.navigationBar.titleTextAttributes = titleAttributes;
            messagenav.navigationBar.titleTextAttributes = titleAttributes;
        }

        self.listController = lvc;
        self.navigationController = listnav;

        UISplitViewController *svc = [[UISplitViewController alloc] initWithNibName:nil bundle:nil];

        if (self.style.tintColor) {
            svc.view.tintColor = self.style.tintColor;
        }

        // display both view controllers in horizontally regular contexts
        svc.preferredDisplayMode = UISplitViewControllerDisplayModeAllVisible;

        svc.delegate = lvc;
        svc.viewControllers = @[listnav, messagenav];
        svc.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;

        [[UAUtils topController] presentViewController:svc animated:animated completion:nil];
    }
}

- (void)display {
    [self display:YES];
}

- (void)displayMessage:(UAInboxMessage *)message animated:(BOOL)animated {
    [self display:animated];
    [self.listController displayMessage:message];
}

- (void)displayMessage:(UAInboxMessage *)message {
    [self displayMessage:message animated:NO];
}

- (void)dismiss:(BOOL)animated {
    [self.navigationController.presentingViewController dismissViewControllerAnimated:animated completion:nil];
    self.listController = nil;
    self.navigationController = nil;
}

- (void)dismiss {
    [self dismiss:YES];
}

@end
