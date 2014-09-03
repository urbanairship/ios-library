
#import <Foundation/Foundation.h>
#import "InboxSampleUserInterface.h"

/**
 * A sample user interface that displays the inbox as a popover.
 *
 * Note: this user interface is for iPad only.
 */
@interface InboxSamplePopoverUserInterface : NSObject<InboxSampleUserInterface, UIPopoverControllerDelegate>

/**
 * InboxSamplePopoverUserInterface initializer.
 *
 * @param controller An instance of UAInboxMessageListController.
 * @param size The desired size of the popover controller.
 */
- (instancetype)initWithMessageListController:(UAInboxMessageListController *)controller popoverSize:(CGSize)size;

- (BOOL)isVisible;
- (void)showInbox;
- (void)hideInbox;

@property(nonatomic, weak) UIViewController *parentController;
@property(nonatomic, strong) UAInboxMessageListController *messageListController;

/**
 * The size of the popover.
 */
@property(nonatomic, assign) CGSize popoverSize;
    
@end
