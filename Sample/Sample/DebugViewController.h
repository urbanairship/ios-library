/* Copyright 2018 Urban Airship and Contributors */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const DeviceInfoSegue;
extern NSString * const InAppAutomationSegue;

@interface DebugViewController : UITableViewController

- (void)deviceInfo;
- (void)inAppAutomation;

@end

NS_ASSUME_NONNULL_END
