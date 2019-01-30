/* Copyright 2010-2019 Urban Airship and Contributors */

@import UIKit;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

// window needs to be strong to match the property inherited from UIApplicationDelegate
@property (strong, nonatomic) IBOutlet UIWindow *window;
@property (weak, nonatomic) IBOutlet UIViewController *controller;

- (void)failIfSimulator;

@end

