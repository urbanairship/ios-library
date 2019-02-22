/* Copyright Urban Airship and Contributors */

#import <UIKit/UIKit.h>

@class UAMessageCenterStyle;
@class UAMessageCenterListViewController;

/**
 * Default implementation of an adaptive message center controller.
 */
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
@property(nonatomic, strong) UAMessageCenterStyle *style;

/**
 * The embedded list view controller.
 */
@property(nonatomic, readonly) UAMessageCenterListViewController *listViewController;

@end
