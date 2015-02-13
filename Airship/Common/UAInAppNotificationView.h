
#import <UIKit/UIKit.h>
#import "UAInAppNotification.h"

/**
 * View class for in-app notifications.
 */
@interface UAInAppNotificationView : UIView

/**
 * UAInAppNotificationView initializer.
 * @param position A `UAInAppNotificationPosition` value, indicating screen position.
 * @param numberOfButtons The number of buttons to display (0-2).
 */
- (instancetype)initWithPosition:(UAInAppNotificationPosition)position numberOfButtons:(NSUInteger)numberOfButtons;

/**
 * The "tab" widget indicating swipability.
 */
@property(nonatomic, readonly)  UIView *tab;

/**
 * The message label displaying notification alert content.
 */
@property(nonatomic, readonly)  UILabel *messageLabel;

/**
 * Button one (may be nil).
 */
@property(nonatomic, readonly)  UIButton *button1;

/**
 * Button two (may be nil).
 */
@property(nonatomic, readonly)  UIButton *button2;

@end

