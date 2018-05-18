
/* Copyright 2018 Urban Airship and Contributors */

#import "UAirship.h"
#import "UAInAppMessageFullScreenView+Internal.h"
#import "UAInAppMessageButtonView+Internal.h"
#import "UAInAppMessageTextView+Internal.h"
#import "UAInAppMessageMediaView+Internal.h"
#import "UAInAppMessageUtils+Internal.h"
#import "UAInAppMessageFullScreenDisplayContent+Internal.h"
#import "UAColorUtils+Internal.h"
#import "UAInAppMessageFullScreenDisplayContent+Internal.h"
#import "UAInAppMessageDismissButton+Internal.h"
#import "UAUtils+Internal.h"
#import "UAViewUtils+Internal.h"


NS_ASSUME_NONNULL_BEGIN

/**
 * Default view padding
 */
CGFloat const FullScreenDefaultPadding = 24.0;

/**
 * Reduced header to body interstitial padding.
 */
CGFloat const FullScreenTextViewInterstitialPadding = -8;

/**
 * Instead of padding body text on the right to avoid the close button
 * it is given extra top padding when it's on top.
 */
CGFloat const FullScreenAdditionalBodyPadding = 16.0;

/**
 * Width of the close button is used to properly pad heading text when
 * it is at the top of a IAM view stack
 */
CGFloat const FullScreenCloseButtonViewWidth = 46.0;

/**
 * Hand tuned value that removes excess vertical safe area to make the
 * top padding look more consistent with the iPhone X nub
 */
CGFloat const FullScreenExcessiveSafeAreaPadding = -8;

NSString *const UAInAppMessageFullScreenViewNibName = @"UAInAppMessageFullScreenView";

@interface UAInAppMessageFullScreenView ()

@property(nonatomic, strong) UAInAppMessageFullScreenStyle *style;

@property (nonatomic, strong) IBOutlet UIStackView *containerStackView;
@property (strong, nonatomic) IBOutlet UIView *footerButtonContainer;
@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;

@property (strong, nonatomic) IBOutlet UIView *closeButtonContainer;
@property (strong, nonatomic) UAInAppMessageDismissButton *closeButton;

@property (nonatomic, strong) UAInAppMessageFullScreenDisplayContent *displayContent;

@property (nonatomic, strong) UAInAppMessageTextView *headerTextView;
@property (nonatomic, strong) UAInAppMessageTextView *bodyTextView;
@property (nonatomic, strong) UAInAppMessageMediaView *mediaView;
@property (nonatomic, strong) UAInAppMessageButtonView *buttonView;

@property (strong, nonatomic) IBOutlet UIView *wrapperView;

@end

@implementation UAInAppMessageFullScreenView

+ (nullable instancetype)fullScreenMessageViewWithDisplayContent:(UAInAppMessageFullScreenDisplayContent *)displayContent
                                                     closeButton:(UAInAppMessageDismissButton *)closeButton
                                                      buttonView:(nullable UAInAppMessageButtonView *)buttonView
                                                    footerButton:(nullable UIButton *)footerButton
                                                       mediaView:(nullable UAInAppMessageMediaView *)mediaView
                                                           style:(nullable UAInAppMessageFullScreenStyle *)style {

    NSString *nibName = UAInAppMessageFullScreenViewNibName;
    NSBundle *bundle = [UAirship resources];

    UAInAppMessageFullScreenView *view = [[bundle loadNibNamed:nibName owner:nil options:nil] firstObject];

    [view configureFullScreenViewWithDisplayContent:displayContent
                                        closeButton:closeButton
                                         buttonView:buttonView
                                       footerButton:footerButton
                                          mediaView:mediaView
                                              style:style];

    return view;
}

- (UAInAppMessageFullScreenContentLayoutType)normalizeContentLayout:(UAInAppMessageFullScreenDisplayContent *)content {
    // If there's no media, normalize to header body media
    if (!content.media) {
        return UAInAppMessageFullScreenContentLayoutHeaderBodyMedia;
    }

    // If header is missing for header media body, but media is present, normalize to media header body
    if (content.contentLayout == UAInAppMessageFullScreenContentLayoutHeaderMediaBody && !content.heading && content.media) {
        return UAInAppMessageFullScreenContentLayoutMediaHeaderBody;
    }

    return (UAInAppMessageFullScreenContentLayoutType)content.contentLayout;
}

- (void)configureFullScreenViewWithDisplayContent:(UAInAppMessageFullScreenDisplayContent *)displayContent
                                      closeButton:(UAInAppMessageDismissButton *)closeButton
                                       buttonView:(nullable UAInAppMessageButtonView *)buttonView
                                     footerButton:(nullable UIButton *)footerButton
                                        mediaView:(nullable UAInAppMessageMediaView *)mediaView
                                            style:(nullable UAInAppMessageFullScreenStyle *)style {

    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.style = style;
    self.mediaView = mediaView;
    self.buttonView = buttonView;

    self.closeButton = closeButton;
    [self.closeButtonContainer addSubview:closeButton];

    [UAViewUtils applyContainerConstraintsToContainer:self.closeButtonContainer containedView:closeButton];

    // Normalize content layout
    UAInAppMessageFullScreenContentLayoutType normalizedContentLayout = [self normalizeContentLayout:displayContent];

    // Add views that belong in the stack - adding views that are nil will result in no-op
    switch (normalizedContentLayout) {
        case UAInAppMessageFullScreenContentLayoutHeaderMediaBody: {
            // Add header
            self.headerTextView = [UAInAppMessageTextView textViewWithTextInfo:displayContent.heading style:style.headerStyle];
            if (self.headerTextView) {
                [self.containerStackView addArrangedSubview:self.headerTextView];

                // Apply special case if no header style is provided
                [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeTop
                                                       onView:self.headerTextView.textLabel
                                                      padding:FullScreenDefaultPadding
                                                      replace:NO];
                
                // Special case for when header is on top
                CGFloat closeButtonPadding = FullScreenCloseButtonViewWidth - FullScreenDefaultPadding;
                [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeTrailing
                                                       onView:self.headerTextView.textLabel
                                                      padding:closeButtonPadding
                                                      replace:NO];
                if (self.displayContent.heading.alignment == UAInAppMessageTextInfoAlignmentCenter) {
                    // Apply equivalent padding to leading constraint if header is centered
                    [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeLeading
                                                           onView:self.headerTextView.textLabel
                                                          padding:closeButtonPadding
                                                          replace:NO];;
                }
            }

            // Add media
            [self.containerStackView addArrangedSubview:mediaView];

            self.bodyTextView = [UAInAppMessageTextView textViewWithTextInfo:displayContent.body style:style.headerStyle];

            // Add body
            if (self.bodyTextView) {

                if (!mediaView) {
                    // Reduce space to header
                    [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeTop
                                                           onView:self.bodyTextView.textLabel
                                                          padding:FullScreenTextViewInterstitialPadding
                                                          replace:NO];
                }

                [self.containerStackView addArrangedSubview:self.bodyTextView];
            }
            break;
        }
        case UAInAppMessageFullScreenContentLayoutHeaderBodyMedia: {
            self.headerTextView = [UAInAppMessageTextView textViewWithTextInfo:displayContent.heading style:style.headerStyle];
            self.bodyTextView = [UAInAppMessageTextView textViewWithTextInfo:displayContent.body style:style.bodyStyle];

            // Add header
            if (self.headerTextView) {
                [self.containerStackView addArrangedSubview:self.headerTextView];
                // Special case for when header is on top
                [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeTop onView:self.headerTextView.textLabel padding:FullScreenDefaultPadding
                                                      replace:NO];

                CGFloat closeButtonPadding = FullScreenCloseButtonViewWidth - FullScreenDefaultPadding;
                [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeTrailing
                                                       onView:self.headerTextView.textLabel
                                                      padding:closeButtonPadding
                                                      replace:NO];
                if (self.displayContent.heading.alignment == UAInAppMessageTextInfoAlignmentCenter) {
                    // Apply equivalent padding to leading constraint if header is centered
                    [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeLeading
                                                           onView:self.headerTextView.textLabel
                                                          padding:closeButtonPadding
                                                          replace:NO];
                }
            }

            // Add body
            if (self.bodyTextView) {
                [self.containerStackView addArrangedSubview:self.bodyTextView];

                // Special case for when body is on top
                if (!self.headerTextView) {
                    [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeTop onView:self.bodyTextView.textLabel padding:(FullScreenDefaultPadding + FullScreenAdditionalBodyPadding)
                                                          replace:NO];
                } else {
                    // Reduce body to header space
                    [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeTop onView:self.bodyTextView.textLabel padding:FullScreenTextViewInterstitialPadding replace:NO];
                }
            }

            // Add media
            [self.containerStackView addArrangedSubview:mediaView];

            break;
        }
        case UAInAppMessageFullScreenContentLayoutMediaHeaderBody: {
            // Add media
            [self.containerStackView addArrangedSubview:mediaView];

            // Add header
            self.headerTextView = [UAInAppMessageTextView textViewWithTextInfo:displayContent.heading style:style.headerStyle];
            if (self.headerTextView) {
                [self.containerStackView addArrangedSubview:self.headerTextView];
            }

            // Add body
            self.bodyTextView = [UAInAppMessageTextView textViewWithTextInfo:displayContent.body style:style.bodyStyle];
            if (self.bodyTextView) {
                [self.containerStackView addArrangedSubview:self.bodyTextView];
            }

            if (self.headerTextView && self.bodyTextView) {
                // Reduce body to header space
                [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeTop onView:self.bodyTextView.textLabel padding:FullScreenTextViewInterstitialPadding replace:NO];
            }

            break;
        }
    }

    // Add style padding to button view
    if (self.buttonView) {
        // Button container is always the last thing in the stack
        [self.containerStackView addArrangedSubview:self.buttonView];

        // Add the style padding
        [UAInAppMessageUtils applyPaddingToView:self.buttonView.buttonContainer padding:style.buttonStyle.additionalPadding replace:NO];
    }

    // Add style padding to media view
    if (self.mediaView) {
        // Set the default media stack padding
        UAPadding *defaultMediaSpacing = [UAPadding paddingWithTop:@0
                                                            bottom:@0
                                                           leading:@(-FullScreenDefaultPadding)
                                                          trailing:@(-FullScreenDefaultPadding)];

        [UAInAppMessageUtils applyPaddingToView:self.mediaView.mediaContainer padding:defaultMediaSpacing replace:YES];

        // Add the style padding
        [UAInAppMessageUtils applyPaddingToView:self.mediaView.mediaContainer padding:style.mediaStyle.additionalPadding replace:NO];
    }

    // Explicitly remove footer view from the superview if footer is nil
    if (footerButton) {
        [self.footerButtonContainer addSubview:footerButton];
        [UAViewUtils applyContainerConstraintsToContainer:self.footerButtonContainer containedView:footerButton];
    } else {
        [self.footerButtonContainer removeFromSuperview];
    }

    // Stack view needs to be behind close view. Interaction with buttons is maintained.
    [self.containerStackView.superview sendSubviewToBack:self.containerStackView];

    self.displayContent = displayContent;
    self.backgroundColor = displayContent.backgroundColor;
    self.scrollView.backgroundColor = displayContent.backgroundColor;

    self.translatesAutoresizingMaskIntoConstraints = NO;
}

-(void)layoutSubviews {
    [super layoutSubviews];

    [self refreshViewForCurrentOrientation];
}

- (void)refreshViewForCurrentOrientation {
    BOOL statusBarShowing = !([UIApplication sharedApplication].isStatusBarHidden);

    if (@available(iOS 11.0, *)) {
        UIWindow *window = [UIApplication sharedApplication].keyWindow;

        // Black out the inset and compensate for excess vertical safe area when iPhone X is horizontal
        if (window.safeAreaInsets.top == 0 && window.safeAreaInsets.left > 0) {
            self.backgroundColor = [UIColor blackColor];
        } else if (window.safeAreaInsets.top > 0 && window.safeAreaInsets.left == 0) {
            self.backgroundColor = self.displayContent.backgroundColor;
        }

        // If the orientation has a bar without inset
        if (window.safeAreaInsets.top == 0 && statusBarShowing) {
            [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeTop
                                                   onView:self.wrapperView
                                                  padding:FullScreenDefaultPadding
                                                  replace:YES];
            [self.wrapperView layoutIfNeeded];
            return;
        }

        // If the orientation has a bar with inset
        if (window.safeAreaInsets.top > 0 && statusBarShowing) {
            [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeTop
                                                   onView:self.wrapperView
                                                  padding:FullScreenExcessiveSafeAreaPadding
                                                  replace:YES];
            [self.wrapperView layoutIfNeeded];
            return;
        }
    } else {
        if (statusBarShowing) {
            [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeTop
                                                   onView:self.wrapperView
                                                  padding:FullScreenDefaultPadding
                                                  replace:YES];
            [self.wrapperView layoutIfNeeded];
            return;
        }
    }

    // Otherwise remove top padding
    [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeTop
                                           onView:self.wrapperView
                                          padding:0
                                          replace:YES];
    [self.wrapperView layoutIfNeeded];
}

@end

NS_ASSUME_NONNULL_END

