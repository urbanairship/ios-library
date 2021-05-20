/* Copyright Airship and Contributors */

#import <UserNotifications/UserNotifications.h>

NS_ASSUME_NONNULL_BEGIN

API_UNAVAILABLE(tvos)
@interface UNNotificationContent (UAAdditions)

#if TARGET_OS_IOS
/**
 * Checks if the notification was sent from Airship.
 *
 * @return YES if it's an Airship notification, otherwise NO.
 */
- (BOOL)isAirshipNotificationContent;
#endif

@end

NS_ASSUME_NONNULL_END
