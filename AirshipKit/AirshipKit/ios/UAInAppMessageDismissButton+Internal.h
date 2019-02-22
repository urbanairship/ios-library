/* Copyright Urban Airship and Contributors */

#import <UIKit/UIKit.h>

@interface UAInAppMessageDismissButton : UIButton

NS_ASSUME_NONNULL_BEGIN

extern CGFloat const CloseButtonIconHeight;
extern CGFloat const CloseButtonIconWidth;

/**
 * The color of the close X if no close icon is provided.
 */
@property (nonatomic, strong, nullable) UIColor *dismissButtonColor;

/**
 * The icon image for the close button. Defaults to an X on a
 * semi-transparent white background if nil.
 */
@property (nonatomic, strong, nullable) UIImage *closeIcon;

/**
 * The factory method for creating a full screen controller.
 *
 * @param iconImageName The icon image name for the close button. Defaults to an X on a
 * semi-transparent white background if nil.
 * @param color The color of the close X if no close icon is provided.
 *
 * @return a configured UAInAppMessageFullScreenView instance.
 */
+ (instancetype)closeButtonWithIconImageName:(nullable NSString *)iconImageName color:(nullable UIColor *)color;

@end

NS_ASSUME_NONNULL_END
