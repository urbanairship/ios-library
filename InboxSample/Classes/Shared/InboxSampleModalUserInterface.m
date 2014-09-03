
#import "InboxSampleModalUserInterface.h"

@implementation InboxSampleModalUserInterface

- (instancetype)initWithMessageListController:(UAInboxMessageListController *)controller {
    self = [super init];
    if (self) {
        self.messageListController = controller;
    }
    return self;
}

- (BOOL)isVisible {
    return self.parentController.presentedViewController != nil;
}

- (void)showInbox {
    UINavigationController *nc =  [[UINavigationController alloc] initWithRootViewController:self.messageListController];
    nc.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;

    [self.parentController presentViewController:nc animated:YES completion:nil];
}

- (void)hideInbox {
    [self.parentController dismissViewControllerAnimated:YES completion:nil];
}

@end
