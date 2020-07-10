/* Copyright Airship and Contributors */

#import <UIKit/UIKit.h>

@class UAMessageCenterStyle;
@class UAMessageCenterListViewController;

/**
 * Default implementation of an adaptive message center controller.
 */
DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0. Instead use UADefaultMessageCenterSplitViewController.")
@interface UAMessageCenterSplitViewController : UISplitViewController

///---------------------------------------------------------------------------------------
/// @name Default Message Center Split View Controller Properties
///---------------------------------------------------------------------------------------

/**
 * An optional predicate for filtering messages.
 */
@property (nonatomic, strong) NSPredicate *filter;

/**
 * The style to apply to the message center
 */
@property(nonatomic, strong) UAMessageCenterStyle *messageCenterStyle;

/**
 * The style to apply to the message center.
 *
 * Note: This property is unavailble in iOS 14. Instead use `messageCenterStyle`.
 */
#if !defined(__IPHONE_14_0)
@property(nonatomic, strong) UAMessageCenterStyle *style;
#endif

/**
 * The embedded list view controller.
 */
@property(nonatomic, readonly) UAMessageCenterListViewController *listViewController;

@end
