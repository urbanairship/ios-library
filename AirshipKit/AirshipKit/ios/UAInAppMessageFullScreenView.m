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
#import "UAInAppMessageCloseButton+Internal.h"
#import "UAUtils+Internal.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const UAInAppMessageFullScreenViewNibName = @"UAInAppMessageFullScreenView";

@interface UAInAppMessageFullScreenView ()

@property (nonatomic, strong) IBOutlet UIStackView *containerStackView;
@property (strong, nonatomic) IBOutlet UIView *footerButtonContainer;
@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;

@property (strong, nonatomic) IBOutlet UIView *closeButtonContainer;
@property (strong, nonatomic) UAInAppMessageCloseButton *closeButton;

@property (nonatomic, strong) UAInAppMessageFullScreenDisplayContent *displayContent;

@property (nonatomic, strong) UAInAppMessageTextView *topTextView;
@property (nonatomic, strong) UAInAppMessageTextView *bottomTextView;
@property (nonatomic, strong) UAInAppMessageMediaView *mediaView;
@property (nonatomic, strong) UAInAppMessageButtonView *buttonView;

@property (nonatomic, strong) UIView *statusBarPaddingView;

@property (strong, nonatomic) IBOutlet UIView *wrapperView;

@end

@implementation UAInAppMessageFullScreenView


+ (instancetype)fullScreenMessageViewWithDisplayContent:(UAInAppMessageFullScreenDisplayContent *)displayContent
                                            closeButton:(UAInAppMessageCloseButton *)closeButton
                                             buttonView:(UAInAppMessageButtonView * _Nullable)buttonView
                                           footerButton:(UIButton * _Nullable)footerButton
                                              mediaView:(UAInAppMessageMediaView * _Nullable)mediaView {

    return [[UAInAppMessageFullScreenView alloc] initFullScreenViewWithDisplayContent:displayContent
                                                                          closeButton:closeButton
                                                                           buttonView:buttonView
                                                                         footerButton:footerButton
                                                                            mediaView:mediaView];
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

- (instancetype)initFullScreenViewWithDisplayContent:(UAInAppMessageFullScreenDisplayContent *)displayContent
                                         closeButton:(UAInAppMessageCloseButton *)closeButton
                                          buttonView:(UAInAppMessageButtonView * _Nullable)buttonView
                                        footerButton:(UIButton * _Nullable)footerButton
                                           mediaView:(UAInAppMessageMediaView * _Nullable)mediaView {

    NSString *nibName = UAInAppMessageFullScreenViewNibName;
    NSBundle *bundle = [UAirship resources];

    self = [[bundle loadNibNamed:nibName owner:self options:nil] firstObject];

    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.mediaView = mediaView;
        self.buttonView = buttonView;

        self.closeButton = closeButton;
        [self.closeButtonContainer addSubview:closeButton];
        [UAInAppMessageUtils applyContainerConstraintsToContainer:self.closeButtonContainer containedView:closeButton];

        self.statusBarPaddingView = [[UIView alloc] init];

        // The padding view has 0 size because the actual padding is supplied by the stack view spacing
        [NSLayoutConstraint constraintWithItem:self.statusBarPaddingView
                                     attribute:NSLayoutAttributeHeight
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:nil
                                     attribute:NSLayoutAttributeNotAnAttribute
                                    multiplier:1
                                      constant:0].active = true;

        self.statusBarPaddingView.backgroundColor = displayContent.backgroundColor;

        // Normalize content layout
        UAInAppMessageFullScreenContentLayoutType normalizedContentLayout = [self normalizeContentLayout:displayContent];

        // Add views that belong in the stack - adding views that are nil will result in no-op
        switch (normalizedContentLayout) {
            case UAInAppMessageFullScreenContentLayoutHeaderMediaBody: {

                // Add header
                self.topTextView = [UAInAppMessageTextView textViewWithHeading:displayContent.heading body:nil onTop:YES];
                if (self.topTextView) {
                    [self.containerStackView addArrangedSubview:self.topTextView];
                }

                // Add media
                if (mediaView) {
                    [self.containerStackView addArrangedSubview:mediaView];
                }

                self.bottomTextView = [UAInAppMessageTextView textViewWithHeading:nil body:displayContent.body onTop:!mediaView && !self.topTextView];
                // Add body
                if (self.bottomTextView) {
                    [self.containerStackView addArrangedSubview:self.bottomTextView];
                }
                break;
            }
            case UAInAppMessageFullScreenContentLayoutHeaderBodyMedia: {
                self.topTextView = [UAInAppMessageTextView textViewWithHeading:displayContent.heading body:nil onTop:YES];
                // Add header
                if (self.topTextView) {
                    [self.containerStackView addArrangedSubview:self.topTextView];
                }

                self.bottomTextView = [UAInAppMessageTextView textViewWithHeading:nil body:displayContent.body onTop:!self.topTextView];
                // Add body
                if (self.bottomTextView) {
                    [self.containerStackView addArrangedSubview:self.bottomTextView];
                }

                // Add media
                if (mediaView) {
                    [self.containerStackView addArrangedSubview:mediaView];
                }

                break;
            }
            case UAInAppMessageFullScreenContentLayoutMediaHeaderBody: {

                if (mediaView) {
                    // Add media
                    [self.containerStackView addArrangedSubview:mediaView];
                }

                self.topTextView = [UAInAppMessageTextView textViewWithHeading:displayContent.heading body:displayContent.body onTop:!mediaView];

                // Add header and body
                if (self.topTextView) {
                    [self.containerStackView addArrangedSubview:self.topTextView];
                }

                break;
            }
        }

        // Button container is always the last thing in the stack
        [self.containerStackView addArrangedSubview:self.buttonView];

        // Add invisible spacer to guarantee it expands instead of other views
        UIView *spacer = [[UIView alloc] initWithFrame:CGRectZero];
        spacer.backgroundColor = [UIColor clearColor];
        [spacer setContentHuggingPriority:1 forAxis:UILayoutConstraintAxisVertical];
        [self.containerStackView addArrangedSubview:spacer];

        // Explicitly remove footer view from the superview if footer is nil
        if (footerButton) {
            [self.footerButtonContainer addSubview:footerButton];
            [UAInAppMessageUtils applyContainerConstraintsToContainer:self.footerButtonContainer containedView:footerButton];
        } else {
            [self.footerButtonContainer removeFromSuperview];
        }

        self.displayContent = displayContent;
        self.backgroundColor = displayContent.backgroundColor;
        self.scrollView.backgroundColor = displayContent.backgroundColor;

        self.translatesAutoresizingMaskIntoConstraints = NO;
    }

    return self;
}

-(void)layoutSubviews {
    [super layoutSubviews];

    UIWindow *window = [UIApplication sharedApplication].keyWindow;

    // Add additional padding from status bar to content on non-iPhone X
    if ([UIDevice currentDevice].orientation == UIDeviceOrientationLandscapeLeft || [UIDevice currentDevice].orientation == UIDeviceOrientationLandscapeRight) {
        [UAInAppMessageUtils applyPadding:0 toView:self.wrapperView attribute:NSLayoutAttributeTop];
    } else {
        // This is a tuned value to make the status bar look nice in portrait
        [UAInAppMessageUtils applyPadding:20 toView:self.wrapperView attribute:NSLayoutAttributeTop];
    }

    if (@available(iOS 11.0, *)) {
        // Black out the inset and compensate for excess vertical safe area when iPhone X is horizontal
        if (window.safeAreaInsets.top == 0 && window.safeAreaInsets.left > 0) {
            self.backgroundColor = [UIColor blackColor];
            [UAInAppMessageUtils applyPadding:0 toView:self.wrapperView attribute:NSLayoutAttributeTop];
        } else if (window.safeAreaInsets.top > 0 && window.safeAreaInsets.left == 0) {
            [UAInAppMessageUtils applyPadding:-16 toView:self.wrapperView attribute:NSLayoutAttributeTop];
            self.backgroundColor = self.displayContent.backgroundColor;
        }
    }

    [self.containerStackView layoutIfNeeded];
}

@end

NS_ASSUME_NONNULL_END

