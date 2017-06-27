/* Copyright 2017 Urban Airship and Contributors */

#import "InboxDelegate.h"
#import "MessageCenterViewController.h"

@interface InboxDelegate ()
@property(nonatomic, strong) UIViewController *rootViewController;
@end

@implementation InboxDelegate

- (instancetype)initWithRootViewController:(UIViewController *)rootViewController {
    self = [super init];
    if (self) {
        self.rootViewController = rootViewController;
    }
    return self;
}

- (MessageCenterViewController *)messageCenterViewController {
    UITabBarController *tabBarController = (UITabBarController *)self.rootViewController;
    return [tabBarController.viewControllers objectAtIndex:2];
}

- (void)showInbox {
    UITabBarController *tabBarController = (UITabBarController *)self.rootViewController;
    tabBarController.selectedIndex = 2;
}

- (void)showMessageForID:(NSString *)messageID {
    [self showInbox];
    [[self messageCenterViewController] displayMessageForID:messageID];
}

@end
