/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "UAPadding.h"
#import "UAInAppMessageStyleProtocol.h"
#import "UAInAppMessageTextStyle.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * The key representing the button additionalPadding in a style plist.
 */
extern NSString *const UAButtonAdditionalPaddingKey;

/**
 * The key representing the button style in a style plist.
 */
extern NSString *const UAButtonStyleKey;

/**
 * The key representing the stacked button spacing in a style plist.
 */
extern NSString *const UAStackedButtonSpacingKey;

/**
 * The key representing the separated button spacing in a style plist.
 */
extern NSString *const UASeparatedButtonSpacingKey;

/**
 * The key representing the button height in a style plist.
 */
extern NSString *const UAButtonHeightKey;

/**
 * Model object representing a custom style to be applied
 * to an in-app message button component. Nil parameters are given
 * default styling.
 */
@interface UAInAppMessageButtonStyle : NSObject

/**
 * Padding adds constant values to the button component's top, bottom, trailing or leading
 * constraints within its parent view.
 */
@property(nonatomic, strong, nullable) UAPadding *additionalPadding;

/**
 * The button text styling.
 */
@property(nonatomic, strong, nullable) UAInAppMessageTextStyle *buttonTextStyle;

/**
 * The button's height.
 */
@property(nonatomic, strong, nullable) NSNumber *buttonHeight;

/**
 * The spacing between buttons in the stacked layout;
 */
@property(nonatomic, strong, nullable) NSNumber *stackedButtonSpacing;

/**
 * The spacing between buttons in the separated layout;
 */
@property(nonatomic, strong, nullable) NSNumber *separatedButtonSpacing;

/**
 * The button border width;
 */
@property(nonatomic, strong, nullable) NSNumber *borderWidth;

/**
 * Text style factory method.
 *
 * @param additionalPadding The button view padding.
 * @param textStyle The button text style.
 * @param buttonHeight The button height.
 * @param stackedButtonSpacing The spacing between stacked buttons.
 * @param separatedButtonSpacing The spacing between separated buttons.
 * @param borderWidth The button border width.
 *
 * @return Button Style with specified styling. Nil parameters will be given
 * default styling.
 */
+ (instancetype)styleWithAdditionalPadding:(nullable UAPadding *)additionalPadding
                           buttonTextStyle:(nullable UAInAppMessageTextStyle *)textStyle
                              buttonHeight:(nullable NSNumber *)buttonHeight
                      stackedButtonSpacing:(nullable NSNumber *)stackedButtonSpacing
                    separatedButtonSpacing:(nullable NSNumber *)separatedButtonSpacing
                               borderWidth:(nullable NSNumber *)borderWidth;

/**
 * Button style factory method for styling from a plist.
 *
 * @param buttonStyle Button style dictionary.
 *
 * @return Button Style with specified styling. Nil parameters will be given
 * default styling
 */
+ (instancetype)styleWithDictionary:(nullable NSDictionary *)buttonStyle;

@end

NS_ASSUME_NONNULL_END

