/* Copyright Airship and Contributors */

#import <UIKit/UIKit.h>

@class UAMessageCenterStyle;

#import "UADefaultMessageCenterListViewController.h"
#import "UAMessageCenterListViewDelegate.h"

/**
 * Default implementation of an adaptive message center controller.
 */
@interface UADefaultMessageCenterSplitViewController : UISplitViewController <UAMessageCenterListViewDelegate>

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
@property(nonatomic, readonly) UADefaultMessageCenterListViewController *listViewController;

/**
 * The embedded message view controller
 */
@property (nonatomic, readonly) UADefaultMessageCenterMessageViewController *messageViewController;

@end
