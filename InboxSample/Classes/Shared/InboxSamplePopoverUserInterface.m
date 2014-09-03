
#import "InboxSamplePopoverUserInterface.h"

@interface InboxSamplePopoverUserInterface ()
@property(nonatomic, strong) UINavigationController *navigationController;
@property(nonatomic, strong) UIPopoverController *popoverController;
@end


@implementation InboxSamplePopoverUserInterface

- (instancetype)initWithMessageListController:(UAInboxMessageListController *)controller popoverSize:(CGSize)size {
    self = [super init];
    if (self) {
        self.messageListController = controller;
        self.popoverSize = size;
    }
    return self;
}

- (void)setMessageListController:(UAInboxMessageListController *)messageListController {

    self.navigationController = [[UINavigationController alloc] initWithRootViewController:messageListController];

    self.popoverController = [[UIPopoverController alloc] initWithContentViewController:self.navigationController];
    self.popoverController.popoverContentSize = self.popoverSize;
    self.popoverController.delegate = self;
    messageListController.contentSizeForViewInPopover = self.popoverSize;


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
