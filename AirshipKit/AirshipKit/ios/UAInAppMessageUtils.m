/* Copyright 2017 Urban Airship and Contributors */

#import "UAGlobal.h"
#import "UAInAppMessageUtils+Internal.h"
#import "UAInAppMessageButtonView+Internal.h"

@implementation UAInAppMessageUtils

+ (void)applyButtonInfo:(UAInAppMessageButtonInfo *)buttonInfo button:(UAInAppMessageButton *)button {
    // TODO add font support
    //NSArray *syles = buttonInfo.label.styles;

    button.backgroundColor = [UAColorUtils colorWithHexString:buttonInfo.backgroundColor];

    [button setTitle:buttonInfo.label.text forState:UIControlStateNormal];
    [button setTitleColor:[UAColorUtils colorWithHexString:buttonInfo.label.color] forState:UIControlStateNormal];

    NSAttributedString *attributedTitle = [[NSAttributedString alloc] init];


    //[button setAttributedTitle: forState:UIControlStateNormal];

    [UAInAppMessageUtils applyTextInfo:buttonInfo.label label:button.titleLabel];
}

// Need to convert this to apply the info to an attributed string so it can be used for both labels and button labels
+ (void)applyTextInfo:(UAInAppMessageTextInfo *)textInfo label:(UILabel *)label {
    label.lineBreakMode = NSLineBreakByWordWrapping;
    label.numberOfLines = 0;
    [label setText:textInfo.text];
    [label setTextAlignment:[UAInAppMessageUtils alignmentWithAlignment:textInfo.alignment]];
    [label setTextColor:[UAColorUtils colorWithHexString:textInfo.color]];
    [label setFont:[UAInAppMessageUtils fontWithFontFamilies:textInfo.fontFamilies size:textInfo.size]];

    label.adjustsFontSizeToFitWidth = YES;
}

+ (NSTextAlignment)alignmentWithAlignment:(NSString *)alignment {
    if ([alignment isEqualToString:UAInAppMessageTextInfoAlignmentLeft]) {
        return NSTextAlignmentLeft;
    } else if ([alignment isEqualToString:UAInAppMessageTextInfoAlignmentCenter]) {
        return NSTextAlignmentCenter;
    } else if ([alignment isEqualToString:UAInAppMessageTextInfoAlignmentRight]) {
        return NSTextAlignmentRight;
    }

    return NSTextAlignmentLeft;
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

+ (void)applyContainerConstraintsToContainer:(UIView *)container containedView:(UIView *)contained {
    if (!container || !contained) {
        UA_LDEBUG(@"Attempted to constrain a nil view");
        return;
    }

    // This is a side effect, but these should be set to NO by default when using autolayout
    container.translatesAutoresizingMaskIntoConstraints = NO;
    contained.translatesAutoresizingMaskIntoConstraints = NO;

    NSLayoutConstraint *centerXConstraint = [NSLayoutConstraint constraintWithItem:contained
                                                                         attribute:NSLayoutAttributeCenterX
                                                                         relatedBy:NSLayoutRelationEqual
                                                                            toItem:container
                                                                         attribute:NSLayoutAttributeCenterX
                                                                        multiplier:1.0f
                                                                          constant:0.0f];

    NSLayoutConstraint *centerYConstraint = [NSLayoutConstraint constraintWithItem:contained
                                                                         attribute:NSLayoutAttributeCenterY
                                                                         relatedBy:NSLayoutRelationEqual
                                                                            toItem:container
                                                                         attribute:NSLayoutAttributeCenterY
                                                                        multiplier:1.0f
                                                                          constant:0.0f];


    NSLayoutConstraint *widthConstraint = [NSLayoutConstraint constraintWithItem:contained
                                                                       attribute:NSLayoutAttributeWidth
                                                                       relatedBy:NSLayoutRelationEqual
                                                                          toItem:container
                                                                       attribute:NSLayoutAttributeWidth
                                                                      multiplier:1.0f
                                                                        constant:0.0f];

    NSLayoutConstraint *heightConstraint = [NSLayoutConstraint constraintWithItem:contained
                                                                        attribute:NSLayoutAttributeHeight
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:container
                                                                        attribute:NSLayoutAttributeHeight
                                                                       multiplier:1.0f
                                                                         constant:0.0f];

    centerXConstraint.active = true;
    centerYConstraint.active = true;
    widthConstraint.active = true;
    heightConstraint.active = true;
}

+ (void)prefetchContentsOfURL:(NSURL *)url WithCache:(NSCache *)cache completionHandler:(void (^)(NSString *cacheKey))completionHandler {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        // This blocks a background thread until download is complete
        NSData *downloadedData = [NSData dataWithContentsOfURL:url];
        NSString *cacheKey = [url absoluteString];

        if (downloadedData) {
            NSString *cachesDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
            NSString *file = [cachesDirectory stringByAppendingPathComponent:cacheKey];
            [downloadedData writeToFile:file atomically:YES];

            [cache setObject:downloadedData forKey:cacheKey];
        }

        // Call back on main queue
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(cacheKey);
        });
    });
}

@end
