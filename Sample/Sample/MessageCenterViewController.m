//
//  MessageCenterViewController.m
//  SampleLib
//
//  Created by Ryan Lepinski on 1/26/16.
//  Copyright © 2016 UA. All rights reserved.
//

#import "MessageCenterViewController.h"
#import <AirshipKit/AirshipKit.h>

@interface MessageCenterViewController ()
@end


@implementation MessageCenterViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    UADefaultMessageCenterListViewController *lvc;
    lvc = [[UADefaultMessageCenterListViewController alloc] initWithNibName:@"UADefaultMessageCenterListViewController"
                                                                     bundle:[UAirship resources]];

    lvc.title = [UAirship defaultMessageCenter].title;
    lvc.style = [UAirship defaultMessageCenter].style;

    UADefaultMessageCenterMessageViewController *mvc;
    mvc = [[UADefaultMessageCenterMessageViewController alloc] initWithNibName:@"UADefaultMessageCenterMessageViewController"
                                                                        bundle:[UAirship resources]];

    mvc.style = [UAirship defaultMessageCenter].style;

    UINavigationController *listnav = [[UINavigationController alloc] initWithRootViewController:lvc];
    UINavigationController *messagenav = [[UINavigationController alloc] initWithRootViewController:mvc];

    if ([UAirship defaultMessageCenter].style.navigationBarColor) {
        listnav.navigationBar.barTintColor = [UAirship defaultMessageCenter].style.navigationBarColor;
        messagenav.navigationBar.barTintColor = [UAirship defaultMessageCenter].style.navigationBarColor;
    }

    NSMutableDictionary *titleAttributes = [NSMutableDictionary dictionary];

    if ([UAirship defaultMessageCenter].style.titleColor) {
        titleAttributes[NSForegroundColorAttributeName] = [UAirship defaultMessageCenter].style.titleColor;
    }

    if ([UAirship defaultMessageCenter].style.titleFont) {
        titleAttributes[NSForegroundColorAttributeName] = [UAirship defaultMessageCenter].style.titleFont;
    }

    if (titleAttributes.count) {
        listnav.navigationBar.titleTextAttributes = titleAttributes;
        messagenav.navigationBar.titleTextAttributes = titleAttributes;
    }

    if ([UAirship defaultMessageCenter].style.tintColor) {
        self.view.tintColor = [UAirship defaultMessageCenter].style.tintColor;
    }

    // display both view controllers in horizontally regular contexts
    self.preferredDisplayMode = UISplitViewControllerDisplayModeAllVisible;

    self.delegate = lvc;
    self.viewControllers = @[listnav, messagenav];
}

@end
