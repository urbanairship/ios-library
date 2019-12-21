/* Copyright Airship and Contributors */

#import "MessageCenterViewController.h"

@interface MessageCenterViewController ()
@property (nonatomic, strong) UADefaultMessageCenterSplitViewDelegate *splitViewDelegate;
@end

@implementation MessageCenterViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.style = [UAMessageCenterStyle styleWithContentsOfFile:@"MessageCenterStyle"];
}

- (void)showInbox {
    [self.listViewController.navigationController popToRootViewControllerAnimated:YES];
}

@end
