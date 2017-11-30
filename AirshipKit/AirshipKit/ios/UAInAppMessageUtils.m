/* Copyright 2017 Urban Airship and Contributors */

#import "UAInAppMessageUtils+Internal.h"
#import "UAInAppMessageButtonView+Internal.h"

@implementation UAInAppMessageUtils

//@property(nonatomic, copy, readonly) NSString *text;
//@property(nonatomic, copy, readonly) NSString *color;
//@property(nonatomic, assign, readonly) NSUInteger size;
//@property(nonatomic, copy, readonly) NSString *alignment;
//@property(nonatomic, copy, readonly) NSArray *styles;

+ (void)applyButtonInfo:(UAInAppMessageButtonInfo *)buttonInfo buttonView:(UAInAppMessageButtonView *)buttonView {
    NSArray *syles = buttonInfo.label.styles;


    for (UIButton *button in buttonView.buttons) {
        button.accessibilityIdentifier = buttonInfo.identifier;

        // Apply styles or somesuch
        for (NSString *style in buttonInfo.label.styles) {

        }

        button.backgroundColor = [UAColorUtils colorWithHexString:buttonInfo.backgroundColor];
        button.layer.cornerRadius = buttonInfo.borderRadius;
        button.layer.masksToBounds = YES;
        button.titleLabel.text = buttonInfo.label.text;
        button.titleLabel.textColor = [UAColorUtils colorWithHexString:buttonInfo.label.color];
        button.titleLabel.font = [UAInAppMessageUtils fontWithFontFamilies:buttonInfo.label.fontFamilies size:buttonInfo.label.size];
    }
}

+ (void)applyTextInfo:(UAInAppMessageTextInfo *)textInfo textView:(UAInAppMessageTextView *)textView {

}

// Don't pay attention to this, this should be an applyButtonInfo method
+ (nullable UIButton *)applyButtonInfo:(UAInAppMessageButtonInfo *)buttonInfo button:(UIButton *)button {

    return button;
}

+ (UIFont *)boldFontWithFont:(UIFont *)font {
    UIFontDescriptor * fontD = [font.fontDescriptor
                                fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold];
    return [UIFont fontWithDescriptor:fontD size:0];
}

+ (UIFont *)italicFontWithFont:(UIFont *)font {
    UIFontDescriptor * fontD = [font.fontDescriptor
                                fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitItalic];
    return [UIFont fontWithDescriptor:fontD size:0];
}

+ (UIFont *)underlineFontWithFont:(UIFont *)font
{
    UIFontDescriptor * fontD = [font.fontDescriptor
                                fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitItalic];
    return [UIFont fontWithDescriptor:fontD size:0];
}

// This should be private
+ (nullable UIFont *)fontWithFontFamilies:(NSArray<NSString *> *)fontFamilies size:(CGFloat)size {
    for (id fontFamily in fontFamilies) {
        if (![fontFamily isKindOfClass:[NSString class]]) {
            continue;
        }

        NSArray<NSString *> *fontNames = [UIFont fontNamesForFamilyName:fontFamily];

        UIFont *font;

        for (NSString *fontName in fontNames) {
            font = [UIFont fontWithName:fontName size:size];

            // Return first valid font
            if (font) {
                return font;
            }
        }
    }

    return nil;
}

@end
