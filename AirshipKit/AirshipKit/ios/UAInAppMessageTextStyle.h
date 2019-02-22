/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "UAPadding.h"
#import "UAInAppMessageStyleProtocol.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * The key representing the additionalPadding in a style plist.
 */
extern NSString *const UATextAdditonalPaddingKey;

/**
 * The key representing the padding in a style plist.
 */
extern NSString *const UATextSpacingKey;

/**
 * The key representing the padding in a style plist.
 */
extern NSString *const UALineSpacingKey;

/**
 * Model object representing a custom style to be applied
 * to an in-app message text component. Nil parameters are given
 * default styling.
 */
@interface UAInAppMessageTextStyle : NSObject

/**
 * Padding adds constant values to the media component's top, bottom, trailing or leading
 * constraints within its parent view.
 */
@property(nonatomic, strong, nullable) UAPadding *additionalPadding;

/**
 * The spacing between letters.
 */
@property(nonatomic, strong, nullable) NSNumber *letterSpacing;

/**
 * The spacing above and below letters.
 */
@property(nonatomic, strong, nullable) NSNumber *lineSpacing;

/**
 * Text style factory method.
 *
 * @param additionalPadding The text view additonal padding, defaults to 0pts.
 * @param letterSpacing The letter spacing, defaults to iOS default letter spacing.
 * @param lineSpacing The line spacing, defaults to iOS default line spacing.
 *
 * @return Text Style with specified styling. Nil parameters will be given
 * default styling
 */
+ (instancetype)styleWithAdditionalPadding:(nullable UAPadding *)additionalPadding
                             letterSpacing:(nullable NSNumber *)letterSpacing
                               lineSpacing:(nullable NSNumber *)lineSpacing;

/**
 * Text style factory method for styling from a plist.
 *
 * @param textStyle Text style dictionary.
 *
 * @return Text Style with specified styling. Nil parameters will be given
 * default styling
 */
+ (instancetype)styleWithDictionary:(nullable NSDictionary *)textStyle;

@end

NS_ASSUME_NONNULL_END

