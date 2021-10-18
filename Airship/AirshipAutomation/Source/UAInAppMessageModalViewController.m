/* Copyright Airship and Contributors */

#import "UAInAppMessageTextView+Internal.h"
#import "UAInAppMessageButtonView+Internal.h"
#import "UAInAppMessageMediaView+Internal.h"
#import "UAInAppMessageModalViewController+Internal.h"
#import "UAInAppMessageUtils+Internal.h"
#import "UAInAppMessageManager+Internal.h"
#import "UAInAppMessageDismissButton+Internal.h"
#import "UAInAppMessageModalStyle.h"
#import "UAInAppMessageResizableViewController+Internal.h"
#import "UAAirshipAutomationCoreImport.h"
#import "UAAutomationResources.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif
NS_ASSUME_NONNULL_BEGIN

@class UAInAppMessageTextView;
@class UAInAppMessageButtonView;
@class UAInAppMessageMediaView;
@class UAInAppMessageModalDisplayContent;

/**
 * Default modal padding.
 */
static CGFloat const ModalDefaultPadding = 24.0;

/**
 * Reduced header to body interstitial padding.
 */
static CGFloat const ModalTextViewInterstitialPadding = -8;

/*
 * Instead of padding body text on the right to avoid the close button
 * it is given extra top padding when it's on top.
 */
static CGFloat const ModalAdditionalBodyPadding = 16.0;

/**
 * Width of the close button is used to properly pad heading text when
 * it is at the top of a IAM view stack
 */
static CGFloat const ModalCloseButtonViewWidth = 46.0;

/**
 * Custom UIView class to handle rounding the border of the modal view.
 */
@interface UAInAppMessageModalView : UIView

/**
 * The modal message's border radius.
 */
@property (nonatomic, assign) CGFloat borderRadius;

@end

@interface UAInAppMessageModalViewController ()

/**
 * The main view of this view controller. The modal view is built on it.
 */
@property (strong, nonatomic) IBOutlet UIView *view;

/**
 * The stack view that holds any scrollable content.
 */
@property (strong, nonatomic) IBOutlet UIStackView *scrollableStack;

/**
 * View to hold close (dismiss) button at top of modal message
 */
@property (weak, nonatomic) IBOutlet UIView *closeButtonContainerView;

/**
 * Close button.
 */
@property (strong, nonatomic) UAInAppMessageDismissButton *closeButton;

/**
 * View to hold buttons
 */
@property (weak, nonatomic) IBOutlet UIView *buttonContainerView;

/**
 * View to hold footer
 */
@property (weak, nonatomic) IBOutlet UIView *footerContainerView;


/**
 * The modal message's media view.
 */
@property (nonatomic, strong) UAInAppMessageMediaView *mediaView;

/**
 * The minimum modal width constraint
 */
@property (nonatomic, strong) NSLayoutConstraint *minimumWidth;

@end

@implementation UAInAppMessageModalViewController

@dynamic view;

+ (instancetype)modalControllerWithDisplayContent:(UAInAppMessageModalDisplayContent *)displayContent
                                        mediaView:(nullable UAInAppMessageMediaView *)mediaView
                                            style:(nullable UAInAppMessageModalStyle *)style {

    return [[self alloc] initWithDisplayContent:displayContent
                                      mediaView:mediaView
                                          style:style];
}

- (instancetype)initWithDisplayContent:(UAInAppMessageModalDisplayContent *)displayContent
                             mediaView:(nullable UAInAppMessageMediaView *)mediaView
                                 style:(nullable UAInAppMessageModalStyle *)style {

    self = [self initWithNibName:@"UAInAppMessageModalViewController" bundle:[UAAutomationResources bundle]];

    if (self) {
        self.displayContent = displayContent;
        self.mediaView = mediaView;
        self.style = style;
        self.closeButton = [self createCloseButton];
    }

    return self;
}

- (nullable UAInAppMessageDismissButton *)createCloseButton {
    UAInAppMessageDismissButton *closeButton = [UAInAppMessageDismissButton closeButtonWithIconImageName:self.style.dismissIconResource
                                                                                                   color:self.displayContent.dismissButtonColor];
    [closeButton addTarget:self
                    action:@selector(buttonTapped:)
          forControlEvents:UIControlEventTouchUpInside];

    return closeButton;
}

#pragma mark -
#pragma mark Core Functionality

- (UAInAppMessageModalContentLayoutType)normalizeContentLayout:(UAInAppMessageModalDisplayContent *)content {

    // If there's no media, normalize to header body media
    if (!content.media) {
        return UAInAppMessageModalContentLayoutHeaderBodyMedia;
    }

    // If header is missing for header media body, but media is present, normalize to media header body
    if (content.contentLayout == UAInAppMessageModalContentLayoutHeaderMediaBody && !content.heading && content.media) {
        return UAInAppMessageModalContentLayoutMediaHeaderBody;
    }

    return (UAInAppMessageModalContentLayoutType)content.contentLayout;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.closeButton.dismissButtonColor = self.displayContent.dismissButtonColor;
    [self.closeButtonContainerView addSubview:self.closeButton];
    [UAViewUtils applyContainerConstraintsToContainer:self.closeButtonContainerView containedView:self.closeButton];

    // Normalize the display content layout
    UAInAppMessageModalContentLayoutType normalizedContentLayout = [self normalizeContentLayout:self.displayContent];

    UAInAppMessageTextView *headerView = [UAInAppMessageTextView textViewWithTextInfo:self.displayContent.heading style:self.style.headerStyle];
    UAInAppMessageTextView *bodyView = [UAInAppMessageTextView textViewWithTextInfo:self.displayContent.body style:self.style.bodyStyle];

    // Apply UI special casing for normalized content layout
    switch (normalizedContentLayout) {
        case UAInAppMessageModalContentLayoutHeaderMediaBody: {
            if (headerView) {
                [self.scrollableStack addArrangedSubview:headerView];

                // Special casing for when header is on top
                [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeTop
                                                       onView:headerView.textLabel
                                                      padding:ModalDefaultPadding
                                                      replace:NO];

                // Special case for when header is on top
                CGFloat closeButtonPadding = ModalCloseButtonViewWidth - ModalDefaultPadding;
                [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeTrailing
                                                       onView:headerView.textLabel
                                                      padding:closeButtonPadding
                                                      replace:NO];
                if (self.displayContent.heading.alignment == UAInAppMessageTextInfoAlignmentCenter) {
                    // Apply equivalent padding to leading constraint if header is centered
                    [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeLeading
                                                           onView:headerView.textLabel
                                                          padding:closeButtonPadding
                                                          replace:NO];
                }
            }

            // Add Media
            [self.scrollableStack addArrangedSubview:self.mediaView];

            // Add Body
            if (bodyView) {
                [self.scrollableStack addArrangedSubview:bodyView];
            }

            break;
        }
        case UAInAppMessageModalContentLayoutHeaderBodyMedia:{

            // Add Header
            if (headerView) {
                [self.scrollableStack addArrangedSubview:headerView];

                // Special casing for when header is on top
                [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeTop
                                                       onView:headerView.textLabel
                                                      padding:ModalDefaultPadding
                                                      replace:NO];
                // Special case for when header is on top
                CGFloat closeButtonPadding = ModalCloseButtonViewWidth - ModalDefaultPadding;
                [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeTrailing
                                                       onView:headerView.textLabel
                                                      padding:closeButtonPadding
                                                      replace:NO];
                if (self.displayContent.heading.alignment == UAInAppMessageTextInfoAlignmentCenter) {
                    // Apply equivalent padding to leading constraint if header is centered
                    [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeLeading
                                                           onView:headerView.textLabel
                                                          padding:closeButtonPadding
                                                          replace:NO];
                }
            }

            // Add body
            if (bodyView) {
                [self.scrollableStack addArrangedSubview:bodyView];

                // Special case for when body is on top
                if (!headerView) {
                    [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeTop
                                                           onView:bodyView.textLabel
                                                          padding:(ModalDefaultPadding + ModalAdditionalBodyPadding)
                                                          replace:NO];
                } else {
                    // Reduce body to header space
                    [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeTop
                                                           onView:bodyView.textLabel
                                                          padding:ModalTextViewInterstitialPadding
                                                          replace:NO];
                }
            }

            // Add Media
            if (self.mediaView) {
                [self.scrollableStack addArrangedSubview:self.mediaView];
            }

            break;
        }
        case UAInAppMessageModalContentLayoutMediaHeaderBody: {
            // Add Media
            if (self.mediaView) {
                [self.scrollableStack addArrangedSubview:self.mediaView];
            }

            // Add Header
            if (headerView) {
                [self.scrollableStack addArrangedSubview:headerView];
            }

            // Add Body
            if (bodyView) {
                [self.scrollableStack addArrangedSubview:bodyView];
            }

            if (headerView && bodyView) {
                // Reduce body to header space
                [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeTop
                                                       onView:bodyView.textLabel
                                                      padding:ModalTextViewInterstitialPadding
                                                      replace:NO];
            }

            break;
        }
    }

    // Only create button view if there are buttons
    if (self.displayContent.buttons.count) {
        UAInAppMessageButtonView *buttonView = [UAInAppMessageButtonView buttonViewWithButtons:self.displayContent.buttons
                                                                                        layout:self.displayContent.buttonLayout
                                                                                         style:self.style.buttonStyle
                                                                                        target:self
                                                                                      selector:@selector(buttonTapped:)];
        if (buttonView) {
            [self.buttonContainerView addSubview:buttonView];
            [UAViewUtils applyContainerConstraintsToContainer:self.buttonContainerView containedView:buttonView];

            // Add the button style padding
            [UAInAppMessageUtils applyPaddingToView:buttonView.buttonContainer padding:self.style.buttonStyle.additionalPadding replace:NO];
        } else {
            [self.buttonContainerView removeFromSuperview];
        }
    } else {
        [self.buttonContainerView removeFromSuperview];
    }

    // Add style padding to media view
    if (self.mediaView) {
        // Set the default media stack padding
        UAPadding *defaultMediaSpacing = [UAPadding paddingWithTop:@0
                                                            bottom:@0
                                                           leading:@(-ModalDefaultPadding)
                                                          trailing:@(-ModalDefaultPadding)];

        [UAInAppMessageUtils applyPaddingToView:self.mediaView.mediaContainer padding:defaultMediaSpacing replace:NO];

        // Add the style padding
        [UAInAppMessageUtils applyPaddingToView:self.mediaView.mediaContainer padding:self.style.mediaStyle.additionalPadding replace:NO];
    }

    // footer view
    UAInAppMessageButton *footerButton = [self createFooterButtonWithButtonInfo:self.displayContent.footer];
    if (footerButton) {
        [self.footerContainerView addSubview:footerButton];
        [UAViewUtils applyContainerConstraintsToContainer:self.footerContainerView containedView:footerButton];
    } else {
        [self.footerContainerView removeFromSuperview];
    }
}

-(void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];

    [self applyMinimumSizeConstraints];
}

// Applies reasonable minimum size constraints to the view's resizable parent
- (void)applyMinimumSizeConstraints {
    CGFloat minConstantWidth = MIN(self.resizableParent.view.frame.size.width - (2 * ModalDefaultPadding), 414 - (2 * ModalDefaultPadding));

    self.minimumWidth.active = false;

    self.minimumWidth = [NSLayoutConstraint constraintWithItem:self.resizableParent.resizableContainer
                                                attribute:NSLayoutAttributeWidth
                                                relatedBy:NSLayoutRelationGreaterThanOrEqual
                                                   toItem:nil
                                                attribute:NSLayoutAttributeNotAnAttribute
                                               multiplier:1
                                                 constant:minConstantWidth];

    self.minimumWidth.active = true;
}

- (nullable UAInAppMessageButton *)createFooterButtonWithButtonInfo:(UAInAppMessageButtonInfo *)buttonInfo {
    if (!buttonInfo) {
        return nil;
    }

    UAInAppMessageButton *footerButton = [UAInAppMessageButton footerButtonWithButtonInfo:buttonInfo];

    [footerButton addTarget:self
                     action:@selector(buttonTapped:)
           forControlEvents:UIControlEventTouchUpInside];

    return footerButton;
}

- (void)buttonTapped:(id)sender {
    // Check for close button
    UAInAppMessageResizableViewController *resizableParent = self.resizableParent;
    
    if ([sender isKindOfClass:[UAInAppMessageDismissButton class]]) {
        [resizableParent dismissWithResolution:[UAInAppMessageResolution userDismissedResolution]];
        return;
    }

    UAInAppMessageButton *button = (UAInAppMessageButton *)sender;
    [UAInAppMessageUtils runActionsForButton:button];
    [resizableParent dismissWithResolution:[UAInAppMessageResolution buttonClickResolutionWithButtonInfo:button.buttonInfo]];
}

@end

NS_ASSUME_NONNULL_END

