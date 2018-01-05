/* Copyright 2017 Urban Airship and Contributors */

#import "UAGlobal.h"
#import "UAInAppMessageUtils+Internal.h"
#import "UAInAppMessageButtonView+Internal.h"

NSString *const UADefaultSerifFont = @"Times New Roman";

@implementation UAInAppMessageUtils

+ (void)applyButtonInfo:(UAInAppMessageButtonInfo *)buttonInfo button:(UAInAppMessageButton *)button {
    button.backgroundColor = buttonInfo.backgroundColor;

    // Title label should resize for text length
    button.titleLabel.numberOfLines = 0;

    NSDictionary *attributes = [UAInAppMessageUtils attributesWithTextInfo:buttonInfo.label];
    NSAttributedString *attributedTitle = [[NSAttributedString alloc] initWithString:buttonInfo.label.text attributes:attributes];

    [button setAttributedTitle:attributedTitle forState:UIControlStateNormal];
}

+ (void)applyTextInfo:(UAInAppMessageTextInfo *)textInfo label:(UILabel *)label {
    // Label should resize for text length
    label.numberOfLines = 0;

    NSDictionary *attributes = [UAInAppMessageUtils attributesWithTextInfo:textInfo];
    NSAttributedString *attributedText = [[NSAttributedString alloc] initWithString:textInfo.text attributes:attributes];

    [label setAttributedText:attributedText];
}

+ (UIStackViewAlignment)stackAlignmentWithTextInfo:(UAInAppMessageTextInfo *)textInfo {
    if (textInfo.alignment == NSTextAlignmentLeft) {
        return UIStackViewAlignmentLeading;
    } else if (textInfo.alignment == NSTextAlignmentCenter) {
        return UIStackViewAlignmentCenter;
    } else if (textInfo.alignment == NSTextAlignmentRight) {
        return UIStackViewAlignmentTrailing;
    }

    return UIStackViewAlignmentLeading;
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

#pragma mark -
#pragma mark Helpers

+ (NSDictionary *)attributesWithTextInfo:(UAInAppMessageTextInfo *)textInfo {
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];

    // Font and style
    UIFont *font = [UAInAppMessageUtils fontWithTextInfo:textInfo];
    [attributes setObject:font forKey:NSFontAttributeName];

    // Underline
    if (textInfo.style == UAInAppMessageTextInfoStyleUnderline) {
        [attributes setObject:[NSNumber numberWithInt:NSUnderlineStyleSingle] forKey:NSUnderlineStyleAttributeName];
    }

    // Color
    [attributes setObject:textInfo.color forKey:NSForegroundColorAttributeName];

    // Alignment and word wrapping
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    [paragraphStyle setLineBreakMode:NSLineBreakByWordWrapping];
    [paragraphStyle setAlignment:[UAInAppMessageUtils alignmentWithTextInfo:textInfo]];
    [attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];

    return attributes;
}

+ (NSTextAlignment)alignmentWithTextInfo:(UAInAppMessageTextInfo *)textInfo {
    return textInfo.alignment;
}

+ (UIFont *)fontWithTextInfo:(UAInAppMessageTextInfo *)textInfo {
    NSString *fontFamily = [UAInAppMessageUtils resolveFontFamily:textInfo.fontFamilies];

    UIFontDescriptorSymbolicTraits traits = 0;

    if (textInfo.style == UAInAppMessageTextInfoStyleBold) {
        traits = traits | UIFontDescriptorTraitBold;
    }

    if (textInfo.style == UAInAppMessageTextInfoStyleItalic) {
        traits = traits | UIFontDescriptorTraitItalic;
    }

    id attributes = @{ UIFontDescriptorFamilyAttribute: fontFamily,
                       UIFontDescriptorTraitsAttribute: @{UIFontSymbolicTrait: [NSNumber numberWithInteger:traits] }};

    UIFontDescriptor *fontDescriptor = [UIFontDescriptor fontDescriptorWithFontAttributes:attributes];

    return [UIFont fontWithDescriptor:fontDescriptor size:textInfo.size];
}

+ (NSString *)resolveFontFamily:(NSArray *)fontFamilies {
    for (id fontFamily in fontFamilies) {
        if (![fontFamily isKindOfClass:[NSString class]]) {
            continue;
        }

        NSString *family = fontFamily;

        if ([fontFamily caseInsensitiveCompare:@"serif"] == NSOrderedSame) {
            family = UADefaultSerifFont;
        }

        if ([fontFamily caseInsensitiveCompare:@"sans-serif"] == NSOrderedSame) {
            family = [UIFont systemFontOfSize:[UIFont systemFontSize]].familyName;
        }

        if ([UIFont fontNamesForFamilyName:family].count) {
            return family;
        }
    }

    UA_LDEBUG(@"Unable to find any available font families %@. Defaulting to system font.", fontFamilies);
    return [UIFont systemFontOfSize:[UIFont systemFontSize]].familyName;
}



@end
