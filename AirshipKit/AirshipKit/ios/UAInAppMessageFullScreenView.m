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

@property (strong, nonatomic) UAInAppMessageCloseButton *closeButton;

@property (nonatomic, strong) UAInAppMessageFullScreenDisplayContent *displayContent;

@property (nonatomic, strong) UAInAppMessageTextView *topTextView;
@property (nonatomic, strong) UAInAppMessageTextView *bottomTextView;
@property (nonatomic, strong) UAInAppMessageMediaView *mediaView;
@property (nonatomic, strong) UAInAppMessageButtonView *buttonView;

@property (nonatomic, strong) UIView *statusBarPaddingView;

@end

@implementation UAInAppMessageFullScreenView

+ (nullable instancetype)fullScreenMessageViewWithDisplayContent:(UAInAppMessageFullScreenDisplayContent *)displayContent
                                                     closeButton:(UAInAppMessageCloseButton *)closeButton
                                                      buttonView:(UAInAppMessageButtonView * _Nullable)buttonView
                                                    footerButton:(UIButton * _Nullable)footerButton
                                                       mediaView:(UAInAppMessageMediaView * _Nullable)mediaView {

    NSString *nibName = UAInAppMessageFullScreenViewNibName;
    NSBundle *bundle = [UAirship resources];

    UAInAppMessageFullScreenView *view = [[bundle loadNibNamed:nibName owner:nil options:nil] firstObject];

    if (view) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        view.mediaView = mediaView;
        view.buttonView = buttonView;

        view.closeButton = closeButton;

        view.statusBarPaddingView = [[UIView alloc] init];

        // The padding view has 0 size because the actual padding is supplied by the stack view spacing
        [NSLayoutConstraint constraintWithItem:view.statusBarPaddingView
                                     attribute:NSLayoutAttributeHeight
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:nil
                                     attribute:NSLayoutAttributeNotAnAttribute
                                    multiplier:1
                                      constant:0].active = true;

        view.statusBarPaddingView.backgroundColor = displayContent.backgroundColor;

        // Add views that belong in the stack - adding views that are nil will result in no-op
        if (displayContent.contentLayout == UAInAppMessageFullScreenContentLayoutHeaderMediaBody) {
            // Close
            UIView *closeView = [view createBarCloseView];
            [view.containerStackView addArrangedSubview:closeView];

            // Top text
            view.topTextView = [UAInAppMessageTextView textViewWithHeading:displayContent.heading body:nil];
            [view.containerStackView addArrangedSubview:view.topTextView];

            // Media
            [view.containerStackView addArrangedSubview:mediaView];

            // Bottom text
            view.bottomTextView = [UAInAppMessageTextView textViewWithHeading:nil body:displayContent.body];
            [view.containerStackView addArrangedSubview:view.bottomTextView];
        } else if (displayContent.contentLayout == UAInAppMessageFullScreenContentLayoutHeaderBodyMedia) {
            // Close
            UIView *closeView = [view createBarCloseView];
            [view.containerStackView addArrangedSubview:closeView];

            // Top text
            view.topTextView = [UAInAppMessageTextView textViewWithHeading:displayContent.heading body:displayContent.body];\
            [view.containerStackView addArrangedSubview:view.topTextView];

            // Media
            [view.containerStackView addArrangedSubview:mediaView];
        } else if (displayContent.contentLayout == UAInAppMessageFullScreenContentLayoutMediaHeaderBody) {

            // Close with media
            UIView *closeView = mediaView != nil ? [view createCompoundCloseView] : [view createBarCloseView];
            [view.containerStackView addArrangedSubview:closeView];

            // Top text with body
            view.topTextView = [UAInAppMessageTextView textViewWithHeading:displayContent.heading body:displayContent.body];
            [view.containerStackView addArrangedSubview:view.topTextView];
        }

        // Button container is always the last thing in the stack
        [view.containerStackView addArrangedSubview:view.buttonView];

        // Add invisible spacer to guarantee it expands instead of other views
        UIView *spacer = [[UIView alloc] initWithFrame:CGRectZero];
        spacer.backgroundColor = [UIColor clearColor];
        [spacer setContentHuggingPriority:1 forAxis:UILayoutConstraintAxisVertical];
        [view.containerStackView addArrangedSubview:spacer];

        // Explicitly remove footer view from the superview if footer is nil
        if (footerButton) {
            [view.footerButtonContainer addSubview:footerButton];
            [UAInAppMessageUtils applyContainerConstraintsToContainer:view.footerButtonContainer containedView:footerButton];
        } else {
            [view.footerButtonContainer removeFromSuperview];
        }

        view.displayContent = displayContent;
        view.backgroundColor = displayContent.backgroundColor;
        view.scrollView.backgroundColor = displayContent.backgroundColor;

        view.translatesAutoresizingMaskIntoConstraints = NO;
    }

    return view;
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

