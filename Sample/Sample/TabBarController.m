/* Copyright Airship and Contributors */

#import "TabBarController.h"

@implementation TabBarController

#ifdef DEBUG
- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Instantiate debug library and add it to the tab bar
    
    // Instantiate debug library storyboard
    UIStoryboard *debugStoryboard = [UIStoryboard storyboardWithName:@"AirshipDebug" bundle:[NSBundle bundleWithIdentifier:@"com.urbanairship.AirshipDebug"]];
    if (!debugStoryboard) {
        return;
    }
    
    // Instantiate debug library's initial view controller
    UIViewController *debugViewController = [debugStoryboard instantiateInitialViewController];
    if (!debugViewController) {
        return;
    }
    
    // Debug library needs to operate in a nav controller
    UINavigationController *debugNavController = [[UINavigationController alloc] initWithRootViewController:debugViewController];
    if (!debugNavController) {
        return;
    }
    
    // Create new tab bar item for debug library
    UITabBarItem *debugItem = [[UITabBarItem alloc] initWithTitle:@"Debug" image:[UIImage imageNamed:@"outline_bug_report_black_36pt"] tag:0];
    if (!debugItem) {
        return;
    }
    debugNavController.tabBarItem = debugItem;
    
    // Add tab to tab bar
    NSMutableArray *viewControllers = [NSMutableArray arrayWithArray:self.viewControllers];
    [viewControllers addObject:debugNavController];
    self.viewControllers = viewControllers;
}
#endif

@end
