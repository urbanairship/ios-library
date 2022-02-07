/* Copyright Airship and Contributors */

#import "MessageCenterViewController.h"

@implementation MessageCenterViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.messageCenterStyle = [UAMessageCenterStyle styleWithContentsOfFile:@"MessageCenterStyle"];
    
    self.messageViewController.extendedLayoutIncludesOpaqueBars = YES;
    self.listViewController.extendedLayoutIncludesOpaqueBars = YES;

}

- (void)showInbox {
    [self.listViewController.navigationController popToRootViewControllerAnimated:YES];
}

@end
