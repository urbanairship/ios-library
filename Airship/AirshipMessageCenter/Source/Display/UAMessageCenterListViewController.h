/* Copyright Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UAMessageCenterMessageViewController.h"
#import "UAMessageCenterListViewDelegate.h"

@class UAInboxMessage;
@class UAMessageCenterStyle;

/**
 * Default implementation of a list-style Message Center UI.
 */
@interface UAMessageCenterListViewController : UIViewController <UITableViewDelegate, UITableViewDataSource,
    UIScrollViewDelegate, UAMessageCenterMessageViewDelegate>

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
 * The view controller displaying the currently displayed message
 */
@property (nonatomic, strong) UAMessageCenterMessageViewController *messageViewController;

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
 * The currently selected index path.
 */
@property (nonatomic, readonly) NSIndexPath *selectedIndexPath;

/**
 * The currently selected message.
 */
@property (nonatomic, readonly) UAInboxMessage *selectedMessage;

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
