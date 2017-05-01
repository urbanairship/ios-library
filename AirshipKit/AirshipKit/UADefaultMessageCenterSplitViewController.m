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

#import "UADefaultMessageCenterSplitViewController.h"
#import "UADefaultMessageCenterListViewController.h"
#import "UADefaultMessageCenterMessageViewController.h"
#import "UAMessageCenterMessageViewController.h"
#import "UADefaultMessageCenter.h"
#import "UADefaultMessageCenterStyle.h"
#import "UAirship.h"
#import "UAMessageCenterLocalization.h"
#import "UAConfig.h"

@interface UADefaultMessageCenterSplitViewController ()

@property(nonatomic, strong) UADefaultMessageCenterListViewController *listViewController;
@property(nonatomic, strong) UIViewController<UAMessageCenterMessageViewProtocol> *messageViewController;
@property (nonatomic, strong) UINavigationController *listNav;
@property (nonatomic, strong) UINavigationController *messageNav;

@end

@implementation UADefaultMessageCenterSplitViewController

- (void)configure {

    self.listViewController = [[UADefaultMessageCenterListViewController alloc] initWithNibName:@"UADefaultMessageCenterListViewController"
                                                                     bundle:[UAirship resources]];
    self.listNav = [[UINavigationController alloc] initWithRootViewController:self.listViewController];

    self.title = UAMessageCenterLocalizedString(@"ua_message_center_title");

    self.delegate = self.listViewController;

    // display both view controllers in horizontally regular contexts
    self.preferredDisplayMode = UISplitViewControllerDisplayModeAllVisible;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];

    if (self) {
        [self configure];
    }

    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];

    if (self) {
        [self configure];
    }

    return self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (!self.messageViewController) {
        if (UAirship.shared.config.useWKWebView) {
            self.messageViewController = [[UAMessageCenterMessageViewController alloc] initWithNibName:@"UAMessageCenterMessageViewController"
                                                                         bundle:[UAirship resources]];
        } else {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
            self.messageViewController = [[UADefaultMessageCenterMessageViewController alloc] initWithNibName:@"UADefaultMessageCenterMessageViewController"
                                                                                bundle:[UAirship resources]];
            ((UADefaultMessageCenterMessageViewController *)self.messageViewController).filter = self.filter;
#pragma GCC diagnostic pop
        }
        
        self.listViewController.messageViewController = self.messageViewController;
        self.messageNav = [[UINavigationController alloc] initWithRootViewController:self.messageViewController];
        self.viewControllers = @[self.listNav, self.messageNav];
    }
}

- (void)setStyle:(UADefaultMessageCenterStyle *)style {
    _style = style;
    self.listViewController.style = style;

    if (style.navigationBarColor) {
        self.listNav.navigationBar.barTintColor = self.style.navigationBarColor;
        self.messageNav.navigationBar.barTintColor = self.style.navigationBarColor;
    }

    // Only apply opaque property if a style is set
    if (style) {
        self.listNav.navigationBar.translucent = !style.navigationBarOpaque;
        self.messageNav.navigationBar.translucent = !style.navigationBarOpaque;
    }

    NSMutableDictionary *titleAttributes = [NSMutableDictionary dictionary];

    if (self.style.titleColor) {
        titleAttributes[NSForegroundColorAttributeName] = self.style.titleColor;
    }

    if (self.style.titleFont) {
        titleAttributes[NSFontAttributeName] = self.style.titleFont;
    }

    if (titleAttributes.count) {
        self.listNav.navigationBar.titleTextAttributes = titleAttributes;
        self.messageNav.navigationBar.titleTextAttributes = titleAttributes;
    }

    if (self.style.tintColor) {
        self.view.tintColor = self.style.tintColor;
    }
}

- (void)setFilter:(NSPredicate *)filter {
    _filter = filter;
    self.listViewController.filter = filter;
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    if ([self.messageViewController isKindOfClass:[UADefaultMessageCenterMessageViewController class]]) {
        ((UADefaultMessageCenterMessageViewController *)self.messageViewController).filter = self.filter;
    }
#pragma GCC diagnostic pop
}

- (void)setTitle:(NSString *)title {
    [super setTitle:title];
    self.listViewController.title = title;
}

@end
