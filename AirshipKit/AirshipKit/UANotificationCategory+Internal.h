/* Copyright 2017 Urban Airship and Contributors */

#import "UANotificationCategory.h"

NS_ASSUME_NONNULL_BEGIN

/*
 * SDK-private extensions to UANotificationCategory
 */
@interface UANotificationCategory ()

///---------------------------------------------------------------------------------------
/// @name Notification Catagories Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Converts a UANotificationCategory into a UIUserNotificationCategory.
 *
 * @return An instance of UIUserNotificationCategory.
 */
- (UIUserNotificationCategory *)asUIUserNotificationCategory;

/**
 * Converts a UANotificationCategory into a UNNotificationCategory.
 *
 * @return An instance of UNNotificationCategory. Will be null on iOS 10 beta 2 and older.
 */
- (null_unspecified UNNotificationCategory *)asUNNotificationCategory;

/**
 * Tests for equivalence with a UIUserNotificationCategory. As UANotificationCategory is a
 * drop-in replacement for UNNotificationCategory, any features not applicable
 * in UIUserNotificationCategory will be ignored.
 *
 * @param category The UIUserNotificationCategory to compare with.
 * @return `YES` if the two categories are equivalent, `NO` otherwise.
 */
- (BOOL)isEqualToUIUserNotificationCategory:(UIUserNotificationCategory *)category;

/**
 * Tests for equivalence with a UNNotificationCategory.
 *
 * @param category The UNNotificationCategory to compare with.
 * @return `YES` if the two categories are equivalent, `NO` otherwise.
 */
- (BOOL)isEqualToUNNotificationCategory:(UNNotificationCategory *)category;

@end

NS_ASSUME_NONNULL_END
