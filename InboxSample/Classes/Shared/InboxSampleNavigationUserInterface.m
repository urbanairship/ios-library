
#import "InboxSampleNavigationUserInterface.h"

@implementation InboxSampleNavigationUserInterface

- (instancetype)initWithMessageListController:(UAInboxMessageListController *)controller {
    self = [super init];
    if (self) {
        self.messageListController = controller;
    }
    return self;
}

- (BOOL)isVisible {
    return self.parentController.navigationController.viewControllers.count > 1;
}

- (void)showInbox {
    [self.parentController.navigationController pushViewController:self.messageListController animated:YES];
}

- (void)hideInbox {
    [self.parentController.navigationController popToRootViewControllerAnimated:YES];
}

@end
