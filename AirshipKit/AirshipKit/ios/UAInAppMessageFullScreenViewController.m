/* Copyright Urban Airship and Contributors */

#import "UAirship.h"
#import "UAUtils+Internal.h"
#import "UAInAppMessageTextView+Internal.h"
#import "UAInAppMessageButtonView+Internal.h"
#import "UAInAppMessageMediaView+Internal.h"
#import "UAInAppMessageFullScreenViewController+Internal.h"
#import "UAInAppMessageUtils+Internal.h"
#import "UAInAppMessageManager+Internal.h"
#import "UAColorUtils+Internal.h"
#import "UAInAppMessageDismissButton+Internal.h"
#import "UAInAppMessageFullScreenStyle.h"
#import "UAViewUtils+Internal.h"

NS_ASSUME_NONNULL_BEGIN

@class UAInAppMessageTextView;
@class UAInAppMessageButtonView;
@class UAInAppMessageMediaView;
@class UAInAppMessageFullScreenDisplayContent;

/**
 * Default animation duration.
 */
double const DefaultFullScreenAnimationDuration = 0.2;

/**
 * Default view padding in points.
 */
CGFloat const FullScreenDefaultPadding = 24.0;

/**
 * Reduced header to body interstitial padding in points.
 */
CGFloat const FullScreenTextViewInterstitialPadding = -8;

/**
 * Instead of padding body text on the right to avoid the close button
 * it is given extra top padding when it's on top, units are points.
 */
CGFloat const FullScreenAdditionalBodyPadding = 16.0;

/**
 * Width of the close button is used to properly pad heading text when
 * it is at the top of a IAM view stack, units are points.
 */
CGFloat const FullScreenCloseButtonViewWidth = 46.0;

/**
 * Hand tuned value that removes excess vertical safe area to make the
 * top padding look more consistent with the iPhone X nub, units are points.
 */
CGFloat const FullScreenExcessiveSafeAreaPadding = -8;

/**
 * The full screen view nib name.
 */
NSString *const UAInAppMessageFullScreenViewNibName = @"UAInAppMessageFullScreenViewController";

@interface UAInAppMessageFullScreenViewController ()

@property (strong, nonatomic) IBOutlet UIView *view;

/**
 * The new window created in front of the app's existing window.
 */
@property (strong, nonatomic, nullable) UIWindow *fullScreenWindow;

/**
 * The identifier of the full screen message.
 */
@property (nonatomic, strong) NSString *messageID;

/**
 * The flag indicating the state of the full screen message.
 */
@property (nonatomic, assign) BOOL isShowing;

/**
 * The full screen display content consisting of the text and image.
 */
@property (nonatomic, strong) UAInAppMessageFullScreenDisplayContent *displayContent;

/**
 * Vertical constraint is used to vertically position the message.
 */
@property (nonatomic, strong) NSLayoutConstraint *verticalConstraint;

/**
 * The completion handler passed in when the message is shown.
 */
@property (nonatomic, copy, nullable) void (^showCompletionHandler)(UAInAppMessageResolution *);

/**
 * Full screen in-app message display style.
 */
@property(nonatomic, strong) UAInAppMessageFullScreenStyle *style;

/**
 * The wrapper view that contains the full screen view contents and is nested inside a scroll view.
 */
@property (strong, nonatomic) IBOutlet UIView *wrapperView;

/**
 * The full screen's stack view that holds the primary view components.
 */
@property (nonatomic, strong) IBOutlet UIStackView *containerStackView;

/**
 * The full screen's footer button container.
 */
@property (strong, nonatomic) IBOutlet UIView *footerButtonContainer;

/**
 * The full screen's scroll view
 */
@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;

/**
 * The full screen's close button container.
 */
@property (strong, nonatomic) IBOutlet UIView *closeButtonContainer;

/**
 * The full screen's close button.
 */
@property (strong, nonatomic) UAInAppMessageDismissButton *closeButton;

/**
 * The full screen's header text view.
 */
@property (nonatomic, strong) UAInAppMessageTextView *headerTextView;

/**
 * The full screen's body text view.
 */
@property (nonatomic, strong) UAInAppMessageTextView *bodyTextView;

/**
 * The full screen's button view.
 */
@property (nonatomic, strong) UAInAppMessageButtonView *buttonView;

/**
 * The full screen's media view.
 */
@property (nonatomic, strong) UAInAppMessageMediaView *mediaView;

@end

@implementation UAInAppMessageFullScreenViewController

@dynamic view;

+ (instancetype)fullScreenControllerWithFullScreenMessageID:(NSString *)messageID
                                             displayContent:(UAInAppMessageFullScreenDisplayContent *)displayContent
                                                  mediaView:(nullable UAInAppMessageMediaView *)mediaView
                                                      style:(UAInAppMessageFullScreenStyle *)style {

    return [[self alloc] initWithFullScreenMessageID:messageID
                                      displayContent:displayContent
                                           mediaView:mediaView
                                               style:style];
}

- (instancetype)initWithFullScreenMessageID:(NSString *)messageID
                             displayContent:(UAInAppMessageFullScreenDisplayContent *)displayContent
                                  mediaView:(nullable UAInAppMessageMediaView *)mediaView
                                      style:(UAInAppMessageFullScreenStyle *)style {
    self = [self initWithNibName:UAInAppMessageFullScreenViewNibName bundle:[UAirship resources]];

    if (self) {
        self.messageID = messageID;
        self.displayContent = displayContent;
        self.mediaView = mediaView;
        self.style = style;
    }

    return self;
}

#pragma mark -
#pragma mark View Controller Lifecycle Methods

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.translatesAutoresizingMaskIntoConstraints = NO;

    [self.fullScreenWindow addSubview:self.view];
    [self.fullScreenWindow makeKeyAndVisible];

    self.buttonView = [UAInAppMessageButtonView buttonViewWithButtons:self.displayContent.buttons
                                                               layout:self.displayContent.buttonLayout
                                                                style:self.style.buttonStyle
                                                               target:self
                                                             selector:@selector(buttonTapped:)];

    self.closeButton = [self createCloseButton];

    UAInAppMessageButton *footerButton = [self addFooterButtonWithButtonInfo:self.displayContent.footer];

    [self.closeButtonContainer addSubview:self.closeButton];

    [UAViewUtils applyContainerConstraintsToContainer:self.closeButtonContainer containedView:self.closeButton];

    // Normalize content layout
    UAInAppMessageFullScreenContentLayoutType normalizedContentLayout = [self normalizeContentLayout:self.displayContent];

    // Add views that belong in the stack - adding views that are nil will result in no-op
    switch (normalizedContentLayout) {
        case UAInAppMessageFullScreenContentLayoutHeaderMediaBody: {
            // Add header
            self.headerTextView = [UAInAppMessageTextView textViewWithTextInfo:self.displayContent.heading style:self.style.headerStyle];
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
            [self.containerStackView addArrangedSubview:self.mediaView];

            self.bodyTextView = [UAInAppMessageTextView textViewWithTextInfo:self.displayContent.body style:self.style.headerStyle];

            // Add body
            if (self.bodyTextView) {

                if (!self.mediaView) {
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
            self.headerTextView = [UAInAppMessageTextView textViewWithTextInfo:self.displayContent.heading style:self.style.headerStyle];
            self.bodyTextView = [UAInAppMessageTextView textViewWithTextInfo:self.displayContent.body style:self.style.bodyStyle];

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
            [self.containerStackView addArrangedSubview:self.mediaView];

            break;
        }
        case UAInAppMessageFullScreenContentLayoutMediaHeaderBody: {
            // Add media
            [self.containerStackView addArrangedSubview:self.mediaView];

            // Add header
            self.headerTextView = [UAInAppMessageTextView textViewWithTextInfo:self.displayContent.heading style:self.style.headerStyle];
            if (self.headerTextView) {
                [self.containerStackView addArrangedSubview:self.headerTextView];
            }

            // Add body
            self.bodyTextView = [UAInAppMessageTextView textViewWithTextInfo:self.displayContent.body style:self.style.bodyStyle];
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
        [UAInAppMessageUtils applyPaddingToView:self.buttonView.buttonContainer padding:self.style.buttonStyle.additionalPadding replace:NO];
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
        [UAInAppMessageUtils applyPaddingToView:self.mediaView.mediaContainer padding:self.style.mediaStyle.additionalPadding replace:NO];
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

    self.view.backgroundColor = self.displayContent.backgroundColor;
    self.scrollView.backgroundColor = self.displayContent.backgroundColor;

    // Add initial constraints to pull the full screen view out of bounds to animate slide in
    [self addInitialConstraintsToParentView:self.fullScreenWindow fullScreenView:self.view];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    BOOL statusBarShowing = !([UIApplication sharedApplication].isStatusBarHidden);

    if (@available(iOS 11.0, *)) {
        UIWindow *window = [UIApplication sharedApplication].keyWindow;

        // Black out the inset and compensate for excess vertical safe area when iPhone X is horizontal
        if (window.safeAreaInsets.top == 0 && window.safeAreaInsets.left > 0) {
            self.view.backgroundColor = [UIColor blackColor];
        } else if (window.safeAreaInsets.top > 0 && window.safeAreaInsets.left == 0) {
            self.view.backgroundColor = self.displayContent.backgroundColor;
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

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.verticalConstraint.constant = 0;

    [UIView animateWithDuration:DefaultFullScreenAnimationDuration delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        [self.fullScreenWindow layoutIfNeeded];
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        self.isShowing = YES;
    }];
}

#pragma mark -
#pragma mark Core Functionality

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


- (void)showWithCompletionHandler:(void (^)(UAInAppMessageResolution *))completionHandler {
    if (self.isShowing) {
        UA_LWARN(@"In-app message full screen view has already been displayed");
        return;
    }

    self.showCompletionHandler = completionHandler;

    // create a new window that covers the entire display
    self.fullScreenWindow = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];

    // make sure window appears above any alerts already showing
    self.fullScreenWindow.windowLevel = UIWindowLevelAlert;

    // add this view controller to the window
    self.fullScreenWindow.rootViewController = self;

    // show the window
    [self.fullScreenWindow makeKeyAndVisible];
}

- (nullable UAInAppMessageDismissButton *)createCloseButton {
    UAInAppMessageDismissButton *closeButton = [UAInAppMessageDismissButton closeButtonWithIconImageName:self.style.dismissIconResource
                                                                                                   color:self.displayContent.dismissButtonColor];
    [closeButton addTarget:self
                    action:@selector(buttonTapped:)
          forControlEvents:UIControlEventTouchUpInside];
    return closeButton;
}

- (nullable UAInAppMessageButton *)addFooterButtonWithButtonInfo:(UAInAppMessageButtonInfo *)buttonInfo {
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
    [[UADispatcher mainDispatcher] dispatchAsync:^{
        self.verticalConstraint.constant = self.view.bounds.size.height;

        [UIView animateWithDuration:DefaultFullScreenAnimationDuration delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            [self.fullScreenWindow layoutIfNeeded];
            [self.view layoutIfNeeded];
        } completion:^(BOOL finished){
            self.isShowing = NO;
            [self.view removeFromSuperview];
            self.fullScreenWindow = nil;

            if (self.showCompletionHandler) {
                self.showCompletionHandler(resolution);
                self.showCompletionHandler = nil;
            }
        }];
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

#pragma mark -
#pragma mark Autolayout and Animation

- (void)addInitialConstraintsToParentView:(UIView *)parentView
                           fullScreenView:(UIView *)fullScreenView {

    self.verticalConstraint = [NSLayoutConstraint constraintWithItem:fullScreenView
                                                           attribute:NSLayoutAttributeBottom
                                                           relatedBy:NSLayoutRelationEqual
                                                              toItem:parentView
                                                           attribute:NSLayoutAttributeBottom
                                                          multiplier:1
                                                            constant:fullScreenView.bounds.size.height];

    self.verticalConstraint.active = YES;

    // Center on X axis
    [NSLayoutConstraint constraintWithItem:fullScreenView
                                 attribute:NSLayoutAttributeCenterX
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:parentView
                                 attribute:NSLayoutAttributeCenterX
                                multiplier:1
                                  constant:0].active = YES;

    // Set width
    [NSLayoutConstraint constraintWithItem:fullScreenView
                                 attribute:NSLayoutAttributeWidth
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:parentView
                                 attribute:NSLayoutAttributeWidth
                                multiplier:1
                                  constant:0].active = YES;

    // Set height
    [NSLayoutConstraint constraintWithItem:fullScreenView
                                 attribute:NSLayoutAttributeHeight
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:parentView
                                 attribute:NSLayoutAttributeHeight
                                multiplier:1
                                  constant:0].active = YES;

    [parentView layoutIfNeeded];
    [fullScreenView layoutIfNeeded];
}

@end

NS_ASSUME_NONNULL_END


