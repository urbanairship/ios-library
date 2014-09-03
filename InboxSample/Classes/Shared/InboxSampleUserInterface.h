
#import <Foundation/Foundation.h>
#import "UAInboxMessageListController.h"

/**
 * A common protocol for the various sample inbox user interfaces
 */
@protocol InboxSampleUserInterface <NSObject>

/**
 * Whether the user interface is currently visible.
 */
- (BOOL)isVisible;

/**
 * Show the inbox.
 */
- (void)showInbox;

/**
 * Hide the inbox
 */
- (void)hideInbox;

/**
 * The message list controller assocaited with ther user interface.
 */
@property(nonatomic, strong) UAInboxMessageListController *messageListController;

/**
 * The parent view controller from which the user interface is displayed.
 */
@property(nonatomic, weak) UIViewController *parentController;

@end
