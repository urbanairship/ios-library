/* Copyright Urban Airship and Contributors */

#import "UAGlobal.h"
#import "UAInAppMessageUtils+Internal.h"
#import "UAInAppMessageButtonView+Internal.h"
#import "UAActionRunner+Internal.h"
#import "UAUtils+Internal.h"
#import "UAirship.h"
#import "UADispatcher+Internal.h"

NSString *const UADefaultSerifFont = @"Times New Roman";
NSString *const UAInAppMessageAdapterCacheName = @"UAInAppMessageAdapterCache";

CGFloat const CloseButtonWidth = 30;
CGFloat const CloseButtonHeight = 30;

@implementation UAInAppMessageUtils

+ (void)applyButtonInfo:(UAInAppMessageButtonInfo *)buttonInfo style:(UAInAppMessageButtonStyle *)style button:(UAInAppMessageButton *)button buttonMargin:(CGFloat)buttonMargin  {
    button.backgroundColor = buttonInfo.backgroundColor;

    // Title label should resize for text length
    button.titleLabel.numberOfLines = 0;

    NSDictionary *attributes = [UAInAppMessageUtils attributesWithTextInfo:buttonInfo.label textStyle:style.buttonTextStyle];

    NSAttributedString *attributedTitle = [[NSAttributedString alloc] initWithString:buttonInfo.label.text attributes:attributes];

    switch (buttonInfo.label.alignment) {
        case UAInAppMessageTextInfoAlignmentLeft:
            button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
            button.contentEdgeInsets = UIEdgeInsetsMake(0, 10, 0, 0);
            break;
        case UAInAppMessageTextInfoAlignmentRight:
            button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
            button.contentEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 10);
            break;
        case UAInAppMessageTextInfoAlignmentCenter:
        case UAInAppMessageTextInfoAlignmentNone:
            button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
            break;
    }

    [button setAttributedTitle:attributedTitle forState:UIControlStateNormal];

    CGFloat defaultButtonHeight = button.titleLabel.intrinsicContentSize.height + 2 * buttonMargin;

    // Style the button height
    CGFloat styledButtonHeight = style.buttonHeight ? [style.buttonHeight floatValue] : defaultButtonHeight;

    if (!button.heightConstraint) {
        button.heightConstraint = [NSLayoutConstraint constraintWithItem:button
                                                               attribute:NSLayoutAttributeHeight
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:nil
                                                               attribute:NSLayoutAttributeNotAnAttribute
                                                              multiplier:1.0f
                                                                constant:styledButtonHeight];
    }

    button.heightConstraint.active = YES;
    button.heightConstraint.constant = styledButtonHeight;
}

+ (void)applyTextInfo:(UAInAppMessageTextInfo *)textInfo style:(UAInAppMessageTextStyle *)style label:(UILabel *)label {
    // Label should resize for text length
    label.numberOfLines = 0;
    label.lineBreakMode = NSLineBreakByWordWrapping;

    NSDictionary *attributes = [UAInAppMessageUtils attributesWithTextInfo:textInfo textStyle:style];
    NSAttributedString *attributedText = [[NSAttributedString alloc] initWithString:textInfo.text attributes:attributes];

    [label setAttributedText:attributedText];
    [label sizeToFit];
    [label.superview layoutIfNeeded];
}

+ (void)applyCloseButtonImageConstraintsToContainer:(UIView *)container closeButtonImageView:(UIImageView *)contained {
    if (!container || !contained) {
        UA_LDEBUG(@"Attempted to constrain a nil view");
        return;
    }

    // This is a side effect, but these should be set to NO by default when using autolayout
    container.translatesAutoresizingMaskIntoConstraints = NO;
    contained.translatesAutoresizingMaskIntoConstraints = NO;

    // Constrain the close button image view to the lower left corner of the touchable button space
    NSLayoutConstraint *widthConstraint = [NSLayoutConstraint constraintWithItem:contained
                                                                       attribute:NSLayoutAttributeWidth
                                                                       relatedBy:NSLayoutRelationEqual
                                                                          toItem:nil
                                                                       attribute:NSLayoutAttributeNotAnAttribute
                                                                      multiplier:1.0f
                                                                        constant:CloseButtonWidth];

    NSLayoutConstraint *heightConstraint = [NSLayoutConstraint constraintWithItem:contained
                                                                        attribute:NSLayoutAttributeHeight
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:nil
                                                                        attribute:NSLayoutAttributeNotAnAttribute
                                                                       multiplier:1.0f
                                                                         constant:CloseButtonHeight];

    // The container and contained are reversed here to allow positive constant increases to result in expected padding
    NSLayoutConstraint *bottomConstraint = [NSLayoutConstraint constraintWithItem:container
                                                                        attribute:NSLayoutAttributeBottom
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:contained
                                                                        attribute:NSLayoutAttributeBottom
                                                                       multiplier:1.0f
                                                                         constant:0.0f];

    // The container and contained are reversed here to allow positive constant increases to result in expected padding
    NSLayoutConstraint *leadingConstraint = [NSLayoutConstraint constraintWithItem:container
                                                                         attribute:NSLayoutAttributeLeading
                                                                         relatedBy:NSLayoutRelationEqual
                                                                            toItem:contained
                                                                         attribute:NSLayoutAttributeLeading
                                                                        multiplier:1.0f
                                                                          constant:0.0f];

    widthConstraint.active = true;
    heightConstraint.active = true;
    bottomConstraint.active = true;
    leadingConstraint.active = true;
}

+ (void)applyPaddingToView:(UIView *)view padding:(UAPadding *)padding replace:(BOOL)replace {
    if (!view) {
        return;
    }

    if (padding.top) {
        [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeTop
                                               onView:view
                                              padding:[padding.top floatValue]
                                              replace:replace];
    }

    if (padding.bottom) {
        [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeBottom
                                               onView:view
                                              padding:[padding.bottom floatValue]
                                              replace:replace];
    }

    if (padding.trailing) {
        [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeTrailing
                                               onView:view
                                              padding:[padding.trailing floatValue]
                                              replace:replace];
    }

    if (padding.leading) {
        [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeLeading
                                               onView:view
                                              padding:[padding.leading floatValue]
                                              replace:replace];
    }

}

+ (void)applyPaddingForAttribute:(NSLayoutAttribute)attribute onView:(UIView *)view padding:(CGFloat)padding replace:(BOOL)replace {
    NSArray *constraints = @[];

    constraints = [constraints arrayByAddingObjectsFromArray:view.constraints];
    constraints = [constraints arrayByAddingObjectsFromArray:view.superview.constraints];

    // Filter constraints to only include those pertaining to the view
    NSArray *filteredConstraints = [constraints filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        NSLayoutConstraint *constraint;
        if ([object isKindOfClass:[NSLayoutConstraint class]]) {
            constraint = (NSLayoutConstraint *)object;
        }

        BOOL matchesView = constraint.firstItem == view || constraint.secondItem == view;
        BOOL matchesSuperView = constraint.firstItem == view.superview || constraint.secondItem == view.superview;
        BOOL matchesLayoutGuide = [constraint.firstItem isKindOfClass:[UILayoutGuide class]] || [constraint.secondItem isKindOfClass:[UILayoutGuide class]];

        // A view and its superview (or an external layout guide) must be present to be considered padding
        return matchesView && (matchesSuperView || matchesLayoutGuide);
    }]];

    for (NSLayoutConstraint *constraint in filteredConstraints) {
        NSLayoutAttribute firstAttribute = constraint.firstAttribute;
        NSLayoutAttribute secondAttribute = constraint.secondAttribute;

        if (firstAttribute == NSLayoutAttributeCenterX ||
            firstAttribute == NSLayoutAttributeCenterY ||
            secondAttribute == NSLayoutAttributeCenterX ||
            secondAttribute == NSLayoutAttributeCenterY ) {
            UA_LWARN(@"Attempted to customize padding on a center-constrainted view, this can cause view ambiguities.");
        }

        // Apply constant regardless of order of participating views
        if ((firstAttribute == attribute) || (secondAttribute == attribute)) {
            constraint.constant = replace ? padding : constraint.constant + padding;
        }
    }
}

// Normalizes style values by stripping out white space
+ (NSDictionary *)normalizeStyleDictionary:(NSDictionary *)keyedValues {
    NSMutableDictionary *normalizedValues = [NSMutableDictionary dictionary];

    for (NSString *key in keyedValues) {

        id value = [keyedValues objectForKey:key];

        // Strip whitespace, if necessary
        if ([value isKindOfClass:[NSString class]]){
            value = [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        }

        [normalizedValues setValue:value forKey:key];
    }

    return normalizedValues;
}

+ (void)prefetchContentsOfURL:(NSURL *)url WithCache:(NSCache *)cache completionHandler:(void (^)(NSString *cacheKey, UAInAppMessagePrepareResult result))completionHandler {

    // Call completion handler on main queue
    void (^complete)(NSString *, UAInAppMessagePrepareResult) = ^(NSString * key, UAInAppMessagePrepareResult result) {
       [[UADispatcher mainDispatcher] dispatchAsync:^{
            completionHandler(key, result);
       }];
    };

    [[[NSURLSession sharedSession]
      downloadTaskWithURL:url
      completionHandler:^(NSURL *temporaryFileLocation, NSURLResponse *response, NSError *error) {

          if (error) {
              UA_LERR(@"Error prefetching media at URL: %@, %@", url, error.localizedDescription);
              return complete(nil, UAInAppMessagePrepareResultCancel);
          }

          if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
              NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
              NSInteger status = httpResponse.statusCode;
              if (status >= 500 && status <= 599) {
                  return complete(nil, UAInAppMessagePrepareResultRetry);
              } else if (status != 200) {
                  return complete(nil, UAInAppMessagePrepareResultCancel);
              }
          }

          NSString *cacheKey = url.absoluteString;
          NSString *cachesDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
          NSString *cachedDestination = [cachesDirectory stringByAppendingPathComponent:cacheKey];

          NSFileManager *fm = [NSFileManager defaultManager];

          // Remove anything currently existing at the destination path
          if ([fm fileExistsAtPath:cachedDestination]) {
              [fm removeItemAtPath:cachedDestination error:&error];

              if (error) {
                  UA_LERR(@"Error removing file %@: %@", cachedDestination, error.localizedDescription);
                  return complete(nil, UAInAppMessagePrepareResultCancel);
              }
          }

          // Move temp file to destination path
          [fm createDirectoryAtPath:[cachedDestination stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
          [fm moveItemAtPath:temporaryFileLocation.path toPath:cachedDestination error:&error];

          if (error) {
              UA_LERR(@"Error moving temp file %@ to %@: %@", temporaryFileLocation.path, cachedDestination, error.localizedDescription);
              return complete(nil, UAInAppMessagePrepareResultCancel);
          }

          NSData *fileData = [NSData dataWithContentsOfFile:cachedDestination
                                                    options:NSDataReadingMappedIfSafe
                                                      error:&error];

          if (error) {
              UA_LERR(@"Error reading media data at %@", cachedDestination);
              return complete(nil, UAInAppMessagePrepareResultCancel);
          }

          [cache setObject:fileData forKey:cacheKey];
          complete(cacheKey, UAInAppMessagePrepareResultSuccess);
      }] resume];
}

#pragma mark -
#pragma mark Helpers

+ (BOOL)isGifData:(NSData *)data {
    BOOL isGifData = NO;
    if (data.length > 3) {
        uint8_t *bytes = (uint8_t *)data.bytes;
        isGifData = ((bytes[0] == 'g' || bytes[0] == 'G') &&
                     (bytes[1] == 'i' || bytes[1] == 'I') &&
                     (bytes[2] == 'f' || bytes[2] == 'F'));
    }
    return isGifData;
}

+ (NSDictionary *)attributesWithTextInfo:(UAInAppMessageTextInfo *)textInfo textStyle:(UAInAppMessageTextStyle *)style {
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];

    // Font and font style
    UIFont *font = [UAInAppMessageUtils fontWithTextInfo:textInfo];
    [attributes setObject:font forKey:NSFontAttributeName];

    // Underline
    if ((textInfo.style & UAInAppMessageTextInfoStyleUnderline) == UAInAppMessageTextInfoStyleUnderline) {
        [attributes setObject:[NSNumber numberWithInt:NSUnderlineStyleSingle] forKey:NSUnderlineStyleAttributeName];
    }

    // Color
    [attributes setObject:textInfo.color forKey:NSForegroundColorAttributeName];

    // Letter Spacing
    if (style.letterSpacing) {
        [attributes setObject:style.letterSpacing forKey:NSKernAttributeName];
    }

    // Alignment and word wrapping
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    [paragraphStyle setLineBreakMode:NSLineBreakByWordWrapping];
    [paragraphStyle setAlignment:[UAInAppMessageUtils alignmentWithTextInfo:textInfo]];

    // Line Spacing
    if (style.lineSpacing) {
        [paragraphStyle setLineSpacing:[style.lineSpacing floatValue]];
        [attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
    }

    [attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];

    return attributes;
}

+ (NSTextAlignment)alignmentWithTextInfo:(UAInAppMessageTextInfo *)textInfo {
    switch (textInfo.alignment) {
        case UAInAppMessageTextInfoAlignmentLeft:
            return NSTextAlignmentLeft;
        case UAInAppMessageTextInfoAlignmentCenter:
            return NSTextAlignmentCenter;
        case UAInAppMessageTextInfoAlignmentRight:
            return NSTextAlignmentRight;
        case UAInAppMessageTextInfoAlignmentNone:
            return NSTextAlignmentLeft;
    }
}

+ (UIFont *)fontWithTextInfo:(UAInAppMessageTextInfo *)textInfo {
    NSString *fontFamily = [UAInAppMessageUtils resolveFontFamily:textInfo.fontFamilies];

    UIFontDescriptorSymbolicTraits traits = 0;

    if ((textInfo.style & UAInAppMessageTextInfoStyleBold) == UAInAppMessageTextInfoStyleBold) {
        traits = traits | UIFontDescriptorTraitBold;
    }

    if ((textInfo.style & UAInAppMessageTextInfoStyleItalic) == UAInAppMessageTextInfoStyleItalic) {
        traits = traits | UIFontDescriptorTraitItalic;
    }

    id attributes = @{ UIFontDescriptorFamilyAttribute: fontFamily,
                       UIFontDescriptorTraitsAttribute: @{UIFontSymbolicTrait: [NSNumber numberWithInteger:traits] }};

    UIFontDescriptor *fontDescriptor = [UIFontDescriptor fontDescriptorWithFontAttributes:attributes];

    return [UIFont fontWithDescriptor:fontDescriptor size:textInfo.sizePoints];
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

+ (void)runActionsForButton:(UAInAppMessageButton *)button {
    if (button.buttonInfo.actions) {
        [UAActionRunner runActionsWithActionValues:button.buttonInfo.actions
                                         situation:UASituationManualInvocation
                                          metadata:nil
                                 completionHandler:^(UAActionResult *result) {
                                     UA_LTRACE(@"Button actions finished running.");
                                 }];
    }
}

#pragma mark -
#pragma mark Adapter utilities

+ (NSCache *)createImageCache {
    NSCache *imageCache = [[NSCache alloc] init];
    [imageCache setName:UAInAppMessageAdapterCacheName];
    [imageCache setCountLimit:1];

    return imageCache;
}

+ (void)prepareMediaView:(UAInAppMessageMediaInfo *)media imageCache:(NSCache *)imageCache completionHandler:(void (^)(UAInAppMessagePrepareResult, UAInAppMessageMediaView *))completionHandler {
    if (!media) {
        completionHandler(UAInAppMessagePrepareResultSuccess,nil);
        return;
    }

    NSURL *mediaURL = [NSURL URLWithString:media.url];

    if (media.type != UAInAppMessageMediaInfoTypeImage) {
        if (![[UAirship shared].whitelist isWhitelisted:mediaURL scope:UAWhitelistScopeOpenURL]) {
            UA_LERR(@"URL %@ not whitelisted. Unable to display media.", mediaURL);
            completionHandler(UAInAppMessagePrepareResultCancel, nil);
            return;
        }

        UAInAppMessageMediaView *mediaView = [UAInAppMessageMediaView mediaViewWithMediaInfo:media];

        completionHandler(UAInAppMessagePrepareResultSuccess, mediaView);
        return;
    }

    // Prefetch image
    [UAInAppMessageUtils prefetchContentsOfURL:mediaURL
                                     WithCache:imageCache
                             completionHandler:^(NSString *cacheKey, UAInAppMessagePrepareResult result) {
                                 UAInAppMessageMediaView *mediaView;
                                 if (cacheKey){
                                     NSData *data = [imageCache objectForKey:cacheKey];
                                     if (data) {
                                         mediaView = [UAInAppMessageMediaView mediaViewWithMediaInfo:media imageData:data];
                                     }
                                 }
                                 completionHandler(result,mediaView);
                             }];
}

+ (BOOL)isReadyToDisplayWithMedia:(UAInAppMessageMediaInfo *)media {
    BOOL noConnection = ([[UAUtils connectionType] isEqual:kUAConnectionTypeNone]);
    if (noConnection && (media.type == UAInAppMessageMediaInfoTypeVideo || media.type == UAInAppMessageMediaInfoTypeYouTube)) {
        return NO;
    }
    return YES;
}

@end

