/* Copyright Urban Airship and Contributors */

@import UIKit;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

/**
 * Indices to the app's tabs
 */
extern NSUInteger const HomeTab;
extern NSUInteger const MessageCenterTab;
extern NSUInteger const DebugTab;

// window needs to be strong to match the property inherited from UIApplicationDelegate
@property (strong, nonatomic) IBOutlet UIWindow *window;
@property (weak, nonatomic) IBOutlet UIViewController *controller;

- (void)failIfSimulator;

@end

