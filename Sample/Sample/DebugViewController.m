/* Copyright Urban Airship and Contributors */

#import "DebugViewController.h"
@import AirshipDebugKit;

NSString *const deviceInfoDeepLink = @"device_info";
NSString *const inAppAutomationDeepLink = @"in_app_automation";
NSString *const eventsDeepLink = @"events";

@interface DebugViewController()

@property (strong, nonatomic) IBOutlet UITableViewCell *deviceInfoCell;
@property (strong, nonatomic) IBOutlet UITableViewCell *inAppAutomationCell;
@property (strong, nonatomic) IBOutlet UITableViewCell *eventsCell;
@property (strong, nonatomic) UIViewController *debugKitViewController;

@end

@implementation DebugViewController

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.debugKitViewController) {
        [self.navigationController pushViewController:self.debugKitViewController animated:YES];
        self.debugKitViewController = nil;
    }
}

- (void)handleDeepLink:(NSArray<NSString *> *)pathComponents {
    NSString *deepLink = pathComponents[0];
    if ([deepLink isEqualToString:deviceInfoDeepLink]) {
        [self deviceInfo];
    } else if ([deepLink isEqualToString:inAppAutomationDeepLink]) {
        [self inAppAutomation];
    } else if ([deepLink isEqualToString:eventsDeepLink]) {
        [self events];
    } else {
        NSLog(@"Unknown deep link = %@",deepLink);
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([indexPath isEqual:[self.tableView indexPathForCell:self.deviceInfoCell]]) {
        [self deviceInfo];
    } else if ([indexPath isEqual:[self.tableView indexPathForCell:self.inAppAutomationCell]]) {
        [self inAppAutomation];
    } else if ([indexPath isEqual:[self.tableView indexPathForCell:self.eventsCell]]) {
        [self events];
    }

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)deviceInfo {
    [self showDebugKitViewController:AirshipDebugKit.deviceInfoViewController];
}

- (void)inAppAutomation {
    [self showDebugKitViewController:AirshipDebugKit.automationViewController];
}

- (void)events {
    [self showDebugKitViewController:AirshipDebugKit.eventsViewController];
}

// Show the DebugKit's view controller if this view controller's view is visible.
// If not, store the DebugKit view controller until the view appears
- (void)showDebugKitViewController:(UIViewController *)debugKitViewController {
    if (debugKitViewController) {
        if (self.isViewLoaded && self.view.window) {
            [self.navigationController pushViewController:debugKitViewController animated:YES];
        } else {
            self.debugKitViewController = debugKitViewController;
        }
    }
}

@end
