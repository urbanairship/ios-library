/* Copyright 2018 Urban Airship and Contributors */

#import "DebugViewController.h"
@import AirshipDebugKit;

@implementation DebugViewController

NSString * const DeviceInfoSegue = @"DeviceInfoSegue";

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    if ([identifier isEqualToString:DeviceInfoSegue]) {
        [self performSegueWithIdentifier:identifier sender:sender];
        return NO;
    }
    return YES;
}

- (void)performSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    if ([identifier isEqualToString:DeviceInfoSegue]) {
        UIViewController *deviceInfoViewController = [AirshipDebugKit instantiateStoryboard:@"DeviceInfo"];
        if (deviceInfoViewController) {
            [self.navigationController pushViewController:deviceInfoViewController animated:true];
        }
    }
}

@end
