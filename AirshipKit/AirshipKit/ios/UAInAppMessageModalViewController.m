/* Copyright 2018 Urban Airship and Contributors */

#import "UAirship.h"
#import "UAUtils+Internal.h"
#import "UAInAppMessageTextView+Internal.h"
#import "UAInAppMessageButtonView+Internal.h"
#import "UAInAppMessageMediaView+Internal.h"
#import "UAInAppMessageModalViewController+Internal.h"
#import "UAInAppMessageUtils+Internal.h"
#import "UAInAppMessageManager+Internal.h"
#import "UAColorUtils+Internal.h"
#import "UAInAppMessageDismissButton+Internal.h"
#import "UAInAppMessageModalStyle.h"

NS_ASSUME_NONNULL_BEGIN

@class UAInAppMessageTextView;
@class UAInAppMessageButtonView;
@class UAInAppMessageMediaView;
@class UAInAppMessageModalDisplayContent;


/**
 * Default modal padding.
 */
CGFloat const ModalDefaultPadding = 24.0;

/**
 * Reduced header to body interstitial padding.
 */
CGFloat const ModalTextViewInterstitialPadding = -8;

/**
 * Instead of padding body text on the right to avoid the close button
 * it is given extra top padding when it's on top.
 */
CGFloat const ModalAdditionalBodyPadding = 16.0;

/**
 * Width of the close button is used to properly pad heading text when
 * it is at the top of a IAM view stack
 */
CGFloat const ModalCloseButtonViewWidth = 46.0;

double const DefaultModalAnimationDuration = 0.2;

/**
 * Custom UIView class to handle rounding the border of the modal view.
 */
@interface UAInAppMessageModalView : UIView

/**
 * The modal message's border radius.
 */
@property (nonatomic,assign) CGFloat borderRadius;

@end

@implementation UAInAppMessageModalView

- (void)layoutSubviews {
    [super layoutSubviews];

    [self applyBorderRounding];
}

- (void)applyBorderRounding {
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.path = [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                           byRoundingCorners:UIRectCornerAllCorners
                                                 cornerRadii:(CGSize){self.borderRadius, self.borderRadius}].CGPath;

    self.layer.mask = maskLayer;
}

@end

@interface UAInAppMessageModalViewController ()

/**
 * The new window created in front of the app's existing window.
 */
@property (strong, nonatomic, nullable) UIWindow *modalWindow;

/**
 * The main view of this view controller. The modal view is built on it.
 */
@property (strong, nonatomic) IBOutlet UIView *view;

/**
 * The modal message view.
 */
@property (weak, nonatomic) IBOutlet UAInAppMessageModalView *modalView;

/**
 * The in-app message modal styling.
 */
@property(nonatomic, strong) UAInAppMessageModalStyle *style;

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
 * The identifier of the modal message.
 */
@property (nonatomic, strong) NSString *messageID;

/**
 * The flag indicating the state of the modal message.
 */
@property (nonatomic, assign) BOOL isShowing;

/**
 * The modal message's media view.
 */
@property (nonatomic, strong) UAInAppMessageMediaView *mediaView;

/**
 * The modal display content.
 */
@property (nonatomic, strong) UAInAppMessageModalDisplayContent *displayContent;

/**
 * The completion handler passed in when the message is shown.
 */
@property (nonatomic, copy, nullable) void (^showCompletionHandler)(UAInAppMessageResolution *);

/**
 * Used to add padding above the stack view - constant defaults to 0
 */
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *scrollableStackToTopConstaint;

@end

@implementation UAInAppMessageModalViewController

@dynamic view;

+ (instancetype)modalControllerWithModalMessageID:(NSString *)messageID
                                   displayContent:(UAInAppMessageModalDisplayContent *)displayContent
                                        mediaView:(nullable UAInAppMessageMediaView *)mediaView
                                            style:(nullable UAInAppMessageModalStyle *)style {

    return [[self alloc] initWithModalMessageID:messageID
                                 displayContent:displayContent
                                      mediaView:mediaView
                                          style:style];
}

- (instancetype)initWithModalMessageID:(NSString *)messageID
                        displayContent:(UAInAppMessageModalDisplayContent *)displayContent
                             mediaView:(nullable UAInAppMessageMediaView *)mediaView
                                 style:(nullable UAInAppMessageModalStyle *)style {
    self = [self initWithNibName:@"UAInAppMessageModalViewController" bundle:[UAirship resources]];

    if (self) {
        self.messageID = messageID;
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

- (void)showWithCompletionHandler:(void (^)(UAInAppMessageResolution * _Nonnull))completionHandler {
    if (self.isShowing) {
        UA_LWARN(@"In-app message modal has already been displayed");
        return;
    }

    self.showCompletionHandler = completionHandler;

    // create a new window that covers the entire display
    self.modalWindow = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];

    // make sure window appears above any alerts already showing
    self.modalWindow.windowLevel = UIWindowLevelAlert;

    // add this view controller to the window
    self.modalWindow.rootViewController = self;

    // show the window
    [self.modalWindow makeKeyAndVisible];
}

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

    self.modalView.borderRadius = self.displayContent.borderRadius;
    self.modalView.backgroundColor = self.displayContent.backgroundColor;

    self.closeButton.dismissButtonColor = self.displayContent.dismissButtonColor;
    [self.closeButtonContainerView addSubview:self.closeButton];
    [UAInAppMessageUtils applyContainerConstraintsToContainer:self.closeButtonContainerView containedView:self.closeButton];

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
                [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeTop onView:headerView.textLabel padding:ModalDefaultPadding
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
            [UAInAppMessageUtils applyContainerConstraintsToContainer:self.buttonContainerView containedView:buttonView];

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
        [UAInAppMessageUtils applyContainerConstraintsToContainer:self.footerContainerView containedView:footerButton];
    } else {
        [self.footerContainerView removeFromSuperview];
    }

    // Add the style padding to the modal itself
    [UAInAppMessageUtils applyPaddingToView:self.modalView padding:self.style.additionalPadding replace:NO];

    // will make opaque as part of animation when view appears
    self.view.alpha = 0;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    // fade in modal message view
    if (self.view.alpha == 0) {
        UA_WEAKIFY(self);
        [UIView animateWithDuration:DefaultModalAnimationDuration animations:^{
            self.view.alpha = 1;

            [self.view setNeedsLayout];
            [self.view layoutIfNeeded];
        } completion:^(BOOL finished) {
            UA_STRONGIFY(self);
            self.isShowing = YES;
        }];
    }
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

- (void)dismissWithResolution:(UAInAppMessageResolution *)resolution  {
    if (self.showCompletionHandler) {
        self.showCompletionHandler(resolution);
        self.showCompletionHandler = nil;
    }

    // fade out modal message view
    UA_WEAKIFY(self);
    [UIView animateWithDuration:DefaultModalAnimationDuration animations:^{
        self.view.alpha = 0;

        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        UA_STRONGIFY(self);
        // teardown
        self.isShowing = NO;
        [self.view removeFromSuperview];
        self.modalWindow = nil;
    }];
}

- (void)buttonTapped:(id)sender {
    // Check for close button
    if ([sender isKindOfClass:[UAInAppMessageDismissButton class]]) {
        [self dismissWithResolution:[UAInAppMessageResolution userDismissedResolution]];
        return;
    }

    UAInAppMessageButton *button = (UAInAppMessageButton *)sender;
    [UAInAppMessageUtils runActionsForButton:button];
    [self dismissWithResolution:[UAInAppMessageResolution buttonClickResolutionWithButtonInfo:button.buttonInfo]];
}

@end

NS_ASSUME_NONNULL_END

