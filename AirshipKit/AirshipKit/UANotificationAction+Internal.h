/* Copyright 2017 Urban Airship and Contributors */

#import "UANotificationAction.h"

NS_ASSUME_NONNULL_BEGIN

/*
 * SDK-private extensions to UANotificationAction
 */
@interface UANotificationAction ()

///---------------------------------------------------------------------------------------
/// @name Notification Action Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Tests for equivalence with a UIUserNotificationAction. As UANotificationAction is a
 * drop-in replacement for UNNotificationAction, any features not applicable
 * in UIUserNotificationAction will be ignored.
 *
 * @param notificationAction The UIUserNotificationAction to compare with.
 * @return `YES` if the two actions are equivalent, `NO` otherwise.
 */
- (BOOL)isEqualToUIUserNotificationAction:(UIUserNotificationAction *)notificationAction;

/**
 * Tests for equivalence with a UNNotificationAction.
 *
 * @param notificationAction The UNNNotificationAction to compare with.
 * @return `YES` if the two actions are equivalent, `NO` otherwise.
 */
- (BOOL)isEqualToUNNotificationAction:(UNNotificationAction *)notificationAction;

@end

NS_ASSUME_NONNULL_END
