/* Copyright Airship and Contributors */

#import "UAContentExtensionViewController.h"
#import "UACarouselViewController.h"

@interface UAContentExtensionViewController ()

#if !TARGET_OS_UIKITFORMAC
<UNNotificationContentExtension>
#endif

@end

@implementation UAContentExtensionViewController

#if !TARGET_OS_UIKITFORMAC
- (void)didReceiveNotification:(UNNotification *)notification {
    UACarouselViewController *carouselViewController = [[UACarouselViewController alloc]init];
    [self addViewController:carouselViewController toContainer:self];
    
    [carouselViewController setupCarouselWithNotification:notification];
}

- (void)didReceiveNotificationResponse:(UNNotificationResponse *)response
                     completionHandler:(void (^)(UNNotificationContentExtensionResponseOption))completion {
    completion(UNNotificationContentExtensionResponseOptionDismissAndForwardAction);
}
#endif

- (void)addViewController:(UIViewController*)controller toContainer:(UIViewController*)containerViewController {
    [containerViewController addChildViewController: controller];
    controller.view.frame = containerViewController.view.frame;
    [containerViewController.view addSubview:controller.view];
    [controller didMoveToParentViewController:containerViewController];    
}

@end


