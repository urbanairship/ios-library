
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
