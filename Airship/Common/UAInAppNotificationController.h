
#import <Foundation/Foundation.h>

@class UAInAppNotification;

/**
 * Controller interface for showing and dismissing in-app
 * notifications.
 */
@interface UAInAppNotificationController : NSObject

/**
 * UAInAppNotificationController initializer.
 * @param notification An instance of UAInAppNotification.
 */
- (instancetype)initWithNotification:(UAInAppNotification *)notification;

/**
 * Show the associated notification.
 */
- (void)show;

/**
 * Dismiss the associated notification.
 */
- (void)dismiss;

@end

