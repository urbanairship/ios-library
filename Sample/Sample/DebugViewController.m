/* Copyright 2018 Urban Airship and Contributors */

#import "DebugViewController.h"
@import AirshipDebugKit;

@interface DebugViewController()

@property (strong, nonatomic) IBOutlet UITableViewCell *deviceInfoCell;
@property (strong, nonatomic) IBOutlet UITableViewCell *inAppAutomationCell;

@end

@implementation DebugViewController

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if ([indexPath isEqual:[self.tableView indexPathForCell:self.deviceInfoCell]]) {
        [self deviceInfo];
    } else if ([indexPath isEqual:[self.tableView indexPathForCell:self.inAppAutomationCell]]) {
        [self inAppAutomation];
    }
}

- (void)deviceInfo {
    if (AirshipDebugKit.deviceInfoViewController) {
        [self.navigationController pushViewController:AirshipDebugKit.deviceInfoViewController animated:YES];
    }
}

- (void)inAppAutomation {
    if (AirshipDebugKit.automationViewController) {
        [self.navigationController pushViewController:AirshipDebugKit.automationViewController animated:YES];
    }
}

@end
