/* Copyright Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UAMessageCenterListViewDelegate.h"
#import "UAMessageCenterMessagePresentationDelegate.h"

@class UAInboxMessage;
@class UAMessageCenterStyle;

/**
 * Default implementation of a list-style Message Center UI.
 */
@interface UADefaultMessageCenterListViewController : UIViewController <UITableViewDelegate, UITableViewDataSource,
    UIScrollViewDelegate>

///---------------------------------------------------------------------------------------
/// @name Default Message Center List View Controller Properties
///---------------------------------------------------------------------------------------

/**
 * The style to apply to the list.
 */
@property (nonatomic, strong) UAMessageCenterStyle *style;

/**
 * An optional predicate for filtering messages.
 */
@property (nonatomic, strong) NSPredicate *filter;

/**
 * Block that will be invoked when a message view controller receives a closeWindow message
 * from the webView.
 *
 * @deprecated Deprecated – to be removed in SDK version 14.0
 */
@property (nonatomic, copy) void (^closeBlock)(BOOL animated) DEPRECATED_MSG_ATTRIBUTE("Deprecated – to be removed in SDK version 14.0.");

/**
 * The list view delegate.
 */
@property (nonatomic, weak) id<UAMessageCenterListViewDelegate> delegate;

/**
 * The presentation delegate.
 */
@property (nonatomic, weak) id<UAMessageCenterMessagePresentationDelegate> messagePresentationDelegate;

/**
 * The currently selected index path.
 */
@property (nonatomic, strong) NSIndexPath *selectedIndexPath;

/**
 * The currently selected message.
 */
@property (nonatomic, strong) UAInboxMessage *selectedMessage;

@end
