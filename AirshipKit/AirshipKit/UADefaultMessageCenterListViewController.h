/* Copyright 2017 Urban Airship and Contributors */

#import <UIKit/UIKit.h>

@class UAInboxMessage;
@class UADefaultMessageCenterStyle;

/**
 * Default implementation of a list-style Message Center UI.
 */
@interface UADefaultMessageCenterListViewController : UIViewController <UITableViewDelegate, UITableViewDataSource,
    UIScrollViewDelegate, UISplitViewControllerDelegate>

/**
 * The style to apply to the list.
 */
@property (nonatomic, strong) UADefaultMessageCenterStyle *style;

/**
 * An optional predicate for filtering messages.
 */
@property (nonatomic, strong) NSPredicate *filter;

/**
 * Block that will be invoked when a message view controller receives a closeWindow message
 * from the webView.
 */
@property (nonatomic, copy) void (^closeBlock)(BOOL animated);

/**
 * Displays a new message, either by updating the currently displayed message or
 * by navigating to a new one.
 *
 * @param message The message to load.
 */
- (void)displayMessage:(UAInboxMessage *)message;

@end
