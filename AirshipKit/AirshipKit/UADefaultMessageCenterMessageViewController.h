/* Copyright 2017 Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UARichContentWindow.h"

@class UAInboxMessage;
@class UADefaultMessageCenterStyle;

/**
 * Default implementation of a view controller for reading Message Center messages.
 *
 * @deprecated Deprecated - to be removed in SDK version 9.0 - please use UAMessageCenterMessageViewController
 */

DEPRECATED_MSG_ATTRIBUTE("Deprecated - to be removed in SDK version 9.0 - please use UAMessageCenterMessageViewController")
@interface UADefaultMessageCenterMessageViewController : UIViewController

/**
 * The UAInboxMessage being displayed.
 *
 * @deprecated Deprecated - to be removed in SDK version 9.0 - please use UAMessageCenterMessageViewController
 */
@property (nonatomic, strong) UAInboxMessage *message DEPRECATED_MSG_ATTRIBUTE("Deprecated - to be removed in SDK version 9.0 - please use UAMessageCenterMessageViewController");

/**
 * An optional predicate for filtering messages.
 *
 * @deprecated Deprecated - to be removed in SDK version 9.0 - please use UAMessageCenterMessageViewController
 */
@property (nonatomic, strong) NSPredicate *filter DEPRECATED_MSG_ATTRIBUTE("Deprecated - to be removed in SDK version 9.0 - please use UAMessageCenterMessageViewController");

/**
 * Block that will be invoked when this class receives a closeWindow message from the webView.
 *
 * @deprecated Deprecated - to be removed in SDK version 9.0 - please use UAMessageCenterMessageViewController
 */
@property (nonatomic, copy) void (^closeBlock)(BOOL animated) DEPRECATED_MSG_ATTRIBUTE("Deprecated - to be removed in SDK version 9.0 - please use UAMessageCenterMessageViewController");

/**
 * Load a UAInboxMessage at a particular index in the message list.
 * @param index The corresponding index in the message list as an integer.
 *
 * @deprecated Deprecated - to be removed in SDK version 9.0 - please use UAMessageCenterMessageViewController
 */
- (void)loadMessageAtIndex:(NSUInteger)index DEPRECATED_MSG_ATTRIBUTE("Deprecated - to be removed in SDK version 9.0 - please use UAMessageCenterMessageViewController");

/**
 * Load a UAInboxMessage by message ID.
 * @param mid The message ID as an NSString.
 *
 * @deprecated Deprecated - to be removed in SDK version 9.0 - please use UAMessageCenterMessageViewController
 */
- (void)loadMessageForID:(NSString *)mid DEPRECATED_MSG_ATTRIBUTE("Deprecated - to be removed in SDK version 9.0 - please use UAMessageCenterMessageViewController");

@end
