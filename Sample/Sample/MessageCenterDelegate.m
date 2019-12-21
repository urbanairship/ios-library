/* Copyright Airship and Contributors */

#import "MessageCenterDelegate.h"
#import "MessageCenterViewController.h"
#import "AppDelegate.h"

@interface MessageCenterDelegate ()
@property(nonatomic, strong) UITabBarController *tabBarController;
@property(nonatomic, strong) MessageCenterViewController *messageCenterViewController;
@end

@implementation MessageCenterDelegate

- (instancetype)initWithRootViewController:(UIViewController *)rootViewController {
    self = [super init];
    if (self) {
        self.tabBarController = (UITabBarController *)rootViewController;
        self.messageCenterViewController = [self.tabBarController.viewControllers objectAtIndex:MessageCenterTab];
    }
    return self;
}

- (void)displayMessageCenterAnimated:(BOOL)animated {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.tabBarController.selectedIndex = MessageCenterTab;
        [self.messageCenterViewController showInbox];
    });
}

- (void)displayMessageCenterForMessageID:(NSString *)messageID animated:(BOOL)animated {
    [self displayMessageCenterAnimated:animated];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.messageCenterViewController displayMessageForID:messageID];
    });
}

 

- (void)dismissMessageCenterAnimated:(BOOL)animated {
    // no-op
}


@end
