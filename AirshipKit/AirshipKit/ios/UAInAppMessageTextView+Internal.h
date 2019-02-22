/* Copyright Urban Airship and Contributors */

#import "UAInAppMessageTextInfo.h"
#import "UAInAppMessageTextStyle.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * The in-app message text view that consists of a view with a constrained label.
 */
@interface UAInAppMessageTextView : UIView

/**
 * The in-app message text view styling.
 */
@property(nonatomic, strong) UAInAppMessageTextStyle *style;

/**
 * The in-app message text label.
 */
@property (strong, nonatomic) UILabel *textLabel;

/**
 * The in-app message text info.
 */
@property (strong, nonatomic) UAInAppMessageTextInfo *textInfo;

/**
 * Text view factory method.
 *
 * @param textInfo The text info.
 * @param style The text style.
 *
 * @return a configured UAInAppMessageTextView instance, or nil if neither heading or body are provided.
 */
+ (nullable instancetype)textViewWithTextInfo:(nullable UAInAppMessageTextInfo *)textInfo style:(nullable UAInAppMessageTextStyle *)style;

@end

NS_ASSUME_NONNULL_END
