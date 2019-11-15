/* Copyright Airship and Contributors */

#import "UAInAppMessageSceneManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface UAInAppMessageSceneManager()

/**
 * Class factory method.
 *
 * @param notificationCenter The notification center on which to observe scene-related events.
 */
+ (instancetype)managerWithNotificationCenter:(NSNotificationCenter *)notificationCenter;

@end

NS_ASSUME_NONNULL_END
