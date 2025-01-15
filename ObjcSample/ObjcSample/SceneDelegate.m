/* Copyright Airship and Contributors */

#import "SceneDelegate.h"
#import "HomeViewController.h"
#import "MessageCenterViewController.h"
#import "PreferenceCenterViewController.h"

@interface SceneDelegate ()

@end

@implementation SceneDelegate


- (void)scene:(UIScene *)scene
willConnectToSession:(UISceneSession *)session
      options:(UISceneConnectionOptions *)connectionOptions {

    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];

    UIViewController *homeVC = [[HomeViewController alloc] init];
    homeVC.title = @"Message Center";

    UIViewController *messageCenterVC = [[MessageCenterViewController alloc] init];
    messageCenterVC.title = @"Message Center";

    UIViewController *preferenceCenterVC = [[PreferenceCenterViewController alloc] init];
    preferenceCenterVC.title = @"Preference Center";

    UITabBarController *tabBarController = [[UITabBarController alloc] init];
    tabBarController.viewControllers = @[homeVC, messageCenterVC, preferenceCenterVC];

    homeVC.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Home"
                                                      image:[UIImage systemImageNamed:@"house"]
                                              selectedImage:[UIImage systemImageNamed:@"house.fill"]];

    messageCenterVC.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Message Center"
                                                               image:[UIImage systemImageNamed:@"tray"]
                                                       selectedImage:[UIImage systemImageNamed:@"tray.fill"]];

    preferenceCenterVC.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Preference Center"
                                                                  image:[UIImage systemImageNamed:@"gear"]
                                                          selectedImage:[UIImage systemImageNamed:@"gearshape.fill"]];

    self.window.rootViewController = tabBarController;

    [self.window makeKeyAndVisible];
}

- (void)sceneDidDisconnect:(UIScene *)scene {
    // Called as the scene is being released by the system.
    // This occurs shortly after the scene enters the background, or when its session is discarded.
    // Release any resources associated with this scene that can be re-created the next time the scene connects.
    // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
}


- (void)sceneDidBecomeActive:(UIScene *)scene {
    // Called when the scene has moved from an inactive state to an active state.
    // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
}


- (void)sceneWillResignActive:(UIScene *)scene {
    // Called when the scene will move from an active state to an inactive state.
    // This may occur due to temporary interruptions (ex. an incoming phone call).
}


- (void)sceneWillEnterForeground:(UIScene *)scene {
    // Called as the scene transitions from the background to the foreground.
    // Use this method to undo the changes made on entering the background.
}


- (void)sceneDidEnterBackground:(UIScene *)scene {
    // Called as the scene transitions from the foreground to the background.
    // Use this method to save data, release shared resources, and store enough scene-specific state information
    // to restore the scene back to its current state.
}


@end
