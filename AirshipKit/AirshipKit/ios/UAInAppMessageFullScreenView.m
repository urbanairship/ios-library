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
#import "UAUtils.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const UAInAppMessageFullScreenViewNibName = @"UAInAppMessageFullScreenView";

@interface UAInAppMessageFullScreenView ()

@property (nonatomic, strong) IBOutlet UIStackView *containerStackView;
@property (strong, nonatomic) IBOutlet UIView *footerButtonContainer;
@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;

@property (strong, nonatomic) UAInAppMessageCloseButton *closeButton;

@property (nonatomic, strong) UAInAppMessageFullScreenDisplayContent *displayContent;

@property (nonatomic, strong) UAInAppMessageTextView *topTextView;
@property (nonatomic, strong) UAInAppMessageTextView *bottomTextView;
@property (nonatomic, strong) UAInAppMessageMediaView *mediaView;
@property (nonatomic, strong) UAInAppMessageButtonView *buttonView;

@property (nonatomic, strong) UIView *statusBarPaddingView;

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

        self.statusBarPaddingView = [[UIView alloc] init];

        // The padding view has 0 size because the actual padding is supplied by the stack view spacing
        [NSLayoutConstraint constraintWithItem:self.statusBarPaddingView
                                     attribute:NSLayoutAttributeHeight
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:nil
                                     attribute:NSLayoutAttributeNotAnAttribute
                                    multiplier:1
                                      constant:0];

        self.statusBarPaddingView.backgroundColor = displayContent.backgroundColor;

        // Add views that belong in the stack - adding views that are nil will result in no-op
        if (displayContent.contentLayout == UAInAppMessageFullScreenContentLayoutHeaderMediaBody) {
            // Close
            UIView *closeView = [self createBarCloseView];
            [self.containerStackView addArrangedSubview:closeView];

            // Top text
            self.topTextView = [UAInAppMessageTextView textViewWithHeading:displayContent.heading body:nil];
            [self.containerStackView addArrangedSubview:self.topTextView];

            // Media
            [self.containerStackView addArrangedSubview:mediaView];

            // Bottom text
            self.bottomTextView = [UAInAppMessageTextView textViewWithHeading:nil body:displayContent.body];
            [self.containerStackView addArrangedSubview:self.bottomTextView];
        } else if (displayContent.contentLayout == UAInAppMessageFullScreenContentLayoutHeaderBodyMedia) {
            // Close
            UIView *closeView = [self createBarCloseView];
            [self.containerStackView addArrangedSubview:closeView];

            // Top text
            self.topTextView = [UAInAppMessageTextView textViewWithHeading:displayContent.heading body:displayContent.body];\
            [self.containerStackView addArrangedSubview:self.topTextView];

            // Media
            [self.containerStackView addArrangedSubview:mediaView];
        } else if (displayContent.contentLayout == UAInAppMessageFullScreenContentLayoutMediaHeaderBody) {

            // Close with media
            UIView *closeView = mediaView != nil ? [self createCompoundCloseView] : [self createBarCloseView];
            [self.containerStackView addArrangedSubview:closeView];

            // Top text with body
            self.topTextView = [UAInAppMessageTextView textViewWithHeading:displayContent.heading body:displayContent.body];
            [self.containerStackView addArrangedSubview:self.topTextView];
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

-(UIView *)createCompoundCloseView {
    UIView *mediaCompoundView = [[UIView alloc] init];
    mediaCompoundView.backgroundColor = [UIColor clearColor];

    [mediaCompoundView addSubview:self.mediaView];
    [UAInAppMessageUtils applyContainerConstraintsToContainer:mediaCompoundView containedView:self.mediaView];
    [mediaCompoundView addSubview:self.closeButton];
    [UAInAppMessageUtils applyCloseButtonConstraintsToContainer:mediaCompoundView closeButton:self.closeButton];

    return mediaCompoundView;
}

-(UIView *)createBarCloseView {
    UIView *barView = [[UIView alloc] init];
    barView.backgroundColor = self.displayContent.backgroundColor;
    [barView addSubview:self.closeButton];
    [UAInAppMessageUtils applyCloseButtonConstraintsToContainer:barView closeButton:self.closeButton];

    [NSLayoutConstraint constraintWithItem:barView
                                 attribute:NSLayoutAttributeHeight
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:self.closeButton
                                 attribute:NSLayoutAttributeHeight
                                multiplier:1.0f
                                  constant:0].active = YES;
    return barView;
}

-(void)layoutSubviews {
    [super layoutSubviews];

    UIWindow *window = [UIApplication sharedApplication].keyWindow;

    if ([UIApplication sharedApplication].statusBarFrame.size.height == 0) {
        [self.containerStackView removeArrangedSubview:self.statusBarPaddingView];
    } else {
        [self.containerStackView insertArrangedSubview:self.statusBarPaddingView atIndex:0];
    }

    if (@available(iOS 11.0, *)) {
        // Black out the inset when iPhone X is horizontal
        if (window.safeAreaInsets.top == 0 && window.safeAreaInsets.left > 0) {
            self.backgroundColor = [UIColor blackColor];
        } else {
            self.backgroundColor = self.displayContent.backgroundColor;
        }
    }

    [self.containerStackView layoutIfNeeded];
}

@end

NS_ASSUME_NONNULL_END

