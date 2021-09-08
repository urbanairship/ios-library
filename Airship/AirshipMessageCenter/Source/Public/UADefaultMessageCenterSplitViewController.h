/* Copyright Airship and Contributors */

#import <UIKit/UIKit.h>

@class UAMessageCenterStyle;

#import "UADefaultMessageCenterListViewController.h"
#import "UADefaultMessageCenterMessageViewController.h"
#import "UAMessageCenterListViewDelegate.h"
#import "UAMessageCenterMessageViewDelegate.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Default implementation of an adaptive message center controller.
 */
NS_SWIFT_NAME(DefaultMessageCenterSplitViewController)
@interface UADefaultMessageCenterSplitViewController : UISplitViewController <UAMessageCenterListViewDelegate, UAMessageCenterMessageViewDelegate>

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
 * Note: This property is unavailable in iOS 14. Instead use `messageCenterStyle`.
 */
#if !defined(__IPHONE_14_0)
@property(nonatomic, strong) UAMessageCenterStyle *style;
#endif

/**
 * The embedded list view controller.
 */
@property(nonatomic, readonly) UADefaultMessageCenterListViewController *listViewController;

/**
 * The embedded message view controller
 */
@property (nonatomic, readonly) UADefaultMessageCenterMessageViewController *messageViewController;

/**
 * Disables 3D touching and long pressing on links in messages.
 */
@property (nonatomic, assign) BOOL disableMessageLinkPreviewAndCallouts;

///---------------------------------------------------------------------------------------
/// @name Default Message Center List View Controller Message Display
///---------------------------------------------------------------------------------------

/**
 * Displays a new message, either by updating the currently displayed message or
 * by navigating to a new one.
 *
 * @param messageID The messageID of the message to load.
 */
- (void)displayMessageForID:(NSString *)messageID;

@end

NS_ASSUME_NONNULL_END
