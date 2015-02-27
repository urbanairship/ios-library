
#import <UIKit/UIKit.h>
#import "UAInAppMessage.h"

/**
 * View class for in-app messages.
 */
@interface UAInAppMessageView : UIView

/**
 * UAInAppMessageView initializer.
 * @param position A `UAInAppMessagePosition` value, indicating screen position.
 * @param numberOfButtons The number of buttons to display (0-2).
 */
- (instancetype)initWithPosition:(UAInAppMessagePosition)position numberOfButtons:(NSUInteger)numberOfButtons;

/**
 * The "tab" widget indicating swipability.
 */
@property(nonatomic, readonly)  UIView *tab;

/**
 * The message label displaying message alert content.
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

