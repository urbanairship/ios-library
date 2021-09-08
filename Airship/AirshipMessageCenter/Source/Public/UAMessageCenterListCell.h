/* Copyright Airship and Contributors */

#import <UIKit/UIKit.h>

@class UAInboxMessage;
@class UAMessageCenterStyle;

/**
 * The UITableViewCell subclass used by the default message center.
 */
NS_SWIFT_NAME(MessageCenterListCell)
@interface UAMessageCenterListCell : UITableViewCell

///---------------------------------------------------------------------------------------
/// @name Default Message Center List Cell Properties
///---------------------------------------------------------------------------------------

/**
 * The style to apply to the cell.
 */
@property (nonatomic, strong) UAMessageCenterStyle *messageCenterStyle;

/**
 * The style to apply to the cell.
 *
 * Note: This property is unavailable in iOS 14. Instead use `messageCenterStyle`.
 */
#if !defined(__IPHONE_14_0)
@property(nonatomic, strong) UAMessageCenterStyle *style;
#endif

/**
 * Displays the message date.
 */
@property (nonatomic, weak) IBOutlet UILabel *date;

/**
 * Displays the message title.
 */
@property (nonatomic, weak) IBOutlet UILabel *title;

/**
 * Indicates whether a message has previously been read.
 */
@property (nonatomic, weak) IBOutlet UIView *unreadIndicator;

/**
 * The message icon view.
 */
@property (nonatomic, weak) IBOutlet UIImageView *listIconView;

///---------------------------------------------------------------------------------------
/// @name Default Message Center List Cell Config
///---------------------------------------------------------------------------------------

/**
 * Configures the cell according to the associated message object.
 * @param message The associated message object.
 */
- (void)setData:(UAInboxMessage *)message;

@end
