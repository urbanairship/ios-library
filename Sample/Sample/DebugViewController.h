/* Copyright Urban Airship and Contributors */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DebugViewController : UITableViewController

- (void)handleDeepLink:(NSArray<NSString *> *)pathcomponents;

@end

NS_ASSUME_NONNULL_END
