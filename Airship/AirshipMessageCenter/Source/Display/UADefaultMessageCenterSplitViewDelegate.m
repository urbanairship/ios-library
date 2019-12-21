/* Copyright Airship and Contributors */

#import "UADefaultMessageCenterSplitViewDelegate.h"

@interface UADefaultMessageCenterSplitViewDelegate ()
@property (nonatomic, strong) UADefaultMessageCenterListViewController *listViewController;
@end

@implementation UADefaultMessageCenterSplitViewDelegate

- (instancetype)initWithListViewController:(UADefaultMessageCenterListViewController *)listViewController {
    self = [super init];
    if (self) {
        self.listViewController = listViewController;
    }
    return self;
}

#pragma mark - UISplitViewControllerDelegate

- (BOOL)splitViewController:(UISplitViewController *)splitViewController collapseSecondaryViewController:(UIViewController *)secondaryViewController ontoPrimaryViewController:(UIViewController *)primaryViewController {
    UADefaultMessageCenterListViewController *lvc = self.listViewController;
    // Only collapse onto the primary (list) controller if there's no currently selected index path or we're in batch editing mode
    return lvc.editing || !(lvc.selectedIndexPath);
}

- (UIViewController *)primaryViewControllerForExpandingSplitViewController:(UISplitViewController *)splitViewController {
    // Returning nil causes the split view controller to default to the the existing primary view controller
    return nil;
}

- (UIViewController *)primaryViewControllerForCollapsingSplitViewController:(UISplitViewController *)splitViewController {
    // Returning nil causes the split view controller to default to the the existing secondary view controller
    return nil;
}

@end
