/* Copyright 2010-2019 Urban Airship and Contributors */

#import "InboxDelegate.h"
#import "MessageCenterViewController.h"

@interface InboxDelegate ()
@property(nonatomic, strong) UITabBarController *tabBarController;
@property(nonatomic, strong) MessageCenterViewController *messageCenterViewController;
@end

@implementation InboxDelegate

- (instancetype)initWithRootViewController:(UIViewController *)rootViewController {
    self = [super init];
    if (self) {
        self.tabBarController = (UITabBarController *)rootViewController;
        self.messageCenterViewController = [self.tabBarController.viewControllers objectAtIndex:2];
    }
    return self;
}

- (void)showInbox {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.tabBarController.selectedIndex = 2;
    });
}

- (void)showMessageForID:(NSString *)messageID {
    [self showInbox];
    [self.messageCenterViewController displayMessageForID:messageID];
}

@end
