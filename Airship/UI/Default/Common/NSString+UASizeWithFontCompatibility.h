

#import <Foundation/Foundation.h>

/**
 * Convenience category for calculating string sizes in a compatible
 * way for both pre and post iOS 7 deployment targets.
 */
@interface NSString (UASizeWithFontCompatibility)

/**
 * Calculate the size of a string wit a supplied font, size constraint,
 * and line break mode. Pre-iOS 7 targets will use the original sizeWithFont
 * method, whereas iOS 7 and above will use the new boundingRectWithSize method.
 *
 * @param font The font to use for computing the string size.
 * @param size The maximum acceptable size for the string. This value is used
 * to calculate where line breaks and wrapping would occur.
 * @param lineBreakMode The line break options for computing the size of the string.
 * For a list of possible values, see NSLineBreakMode.
 */
- (CGSize)uaSizeWithFont:(UIFont *)font
        constrainedToSize:(CGSize)size
            lineBreakMode:(NSLineBreakMode)lineBreakMode;
@end
