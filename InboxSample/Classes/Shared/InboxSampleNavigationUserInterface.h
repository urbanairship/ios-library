
#import <Foundation/Foundation.h>
#import "InboxSampleUserInterface.h"

/**
 * A sample user interface that displays the inbox in a navigation controller
 */
@interface InboxSampleNavigationUserInterface : NSObject<InboxSampleUserInterface>

/**
 * InboxSampleNavigationUserInterface initializer.
 *
 * @param controller An instance of UAInboxMessageListController.
 */
- (instancetype)initWithMessageListController:(UAInboxMessageListController *)controller;

- (BOOL)isVisible;
- (void)showInbox;
- (void)hideInbox;

@property(nonatomic, weak) UIViewController *parentController;
@property(nonatomic, strong) UAInboxMessageListController *messageListController;

@end
