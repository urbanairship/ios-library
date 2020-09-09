/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>
#if !TARGET_OS_UIKITFORMAC
#import <UserNotificationsUI/UserNotificationsUI.h>
#endif
#import "UAGlobal.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * The view controller for the carousel template
 */
@interface UACarouselViewController : UIViewController

- (void)setupCarouselWithNotification:(UNNotification *)notification;

@end

NS_ASSUME_NONNULL_END
