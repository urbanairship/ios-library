/* Copyright 2018 Urban Airship and Contributors */

#import "UAirship.h"
#import "UAInAppMessageBannerView+Internal.h"
#import "UAInAppMessageBannerContentView+Internal.h"
#import "UAInAppMessageButtonView+Internal.h"
#import "UAInAppMessageUtils+Internal.h"
#import "UAInAppMessageBannerDisplayContent+Internal.h"
#import "UAColorUtils+Internal.h"
#import "UAUtils+Internal.h"

#import "UAInAppMessageBannerDisplayContent+Internal.h"

NS_ASSUME_NONNULL_BEGIN

// UAInAppMessageBannerContentView nib name
NSString *const UAInAppMessageBannerViewNibName = @"UAInAppMessageBannerView";
CGFloat const VerticalPaddingToSafeArea = 20;
CGFloat const BannerIsBeingTappedAlpha = 0.7;
CGFloat const DefaultBannerHeightPadding = 60;

CGFloat const ShadowOffset = 2.0;
CGFloat const ShadowRadius = 4.0;
CGFloat const ShadowOpacity = 0.5;

@interface UAInAppMessageBannerView ()

@property (strong, nonatomic) IBOutlet UIView *containerView;
@property (nonatomic, strong) IBOutlet UIView *bannerContentContainerView;
@property (nonatomic, strong) IBOutlet UIView *buttonContainerView;

@property (strong, nonatomic) IBOutlet UIView *tab;

@property (nonatomic, strong) UAInAppMessageBannerContentView *bannerContentView;
@property (nonatomic, strong) UAInAppMessageButtonView *buttonView;

@property (nonatomic, strong) UAInAppMessageBannerDisplayContent *displayContent;
@property (nonatomic, assign) UAInAppMessageButtonRounding rounding;

@property (strong, nonatomic) IBOutlet NSLayoutConstraint *topConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *bottomConstraint;

@property (strong, nonatomic) IBOutlet NSLayoutConstraint *contentTopConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *contentBottomConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *noButtonsContentBottomConstraint;
@property (strong, nonatomic) NSLayoutConstraint *heightConstraint;


@end

@implementation UAInAppMessageBannerView

+ (instancetype)bannerMessageViewWithDisplayContent:(UAInAppMessageBannerDisplayContent *)displayContent
                                  bannerContentView:(UAInAppMessageBannerContentView *)contentView
                                         buttonView:(UAInAppMessageButtonView * _Nullable)buttonView {

    NSString *nibName = UAInAppMessageBannerViewNibName;
    NSBundle *bundle = [UAirship resources];
    CGFloat shadowOffset;
    UAInAppMessageBannerView *view;
    
    // Top and bottom banner views are firstObject and lastObject, respectively.
    switch (displayContent.placement) {
        case UAInAppMessageBannerPlacementTop:
            view = [[bundle loadNibNamed:nibName owner:nil options:nil] firstObject];
            shadowOffset = ShadowOffset;
            if (view) {
                view.rounding = UIRectCornerBottomLeft | UIRectCornerBottomRight;
            }
            break;
        case UAInAppMessageBannerPlacementBottom:
            view = [[bundle loadNibNamed:nibName owner:nil options:nil] lastObject];
            shadowOffset = -ShadowOffset;
            if (view) {
                view.rounding = UIRectCornerTopLeft | UIRectCornerTopRight;
            }
            break;
    }

    if (view) {
        [view addBannerContentView:contentView];

        if (buttonView) {
            [view addButtonView:buttonView];
        } else {
            [view.buttonContainerView removeFromSuperview];
        }

        view.displayContent = displayContent;
        // The layer color is set to background color to preserve rounding and shadow
        view.backgroundColor = [UIColor clearColor];

        view.layer.shadowOffset = CGSizeMake(0, shadowOffset);
        view.layer.shadowRadius = ShadowRadius;
        
        view.translatesAutoresizingMaskIntoConstraints = NO;

        view.layer.shadowOffset = CGSizeMake(shadowOffset/2, shadowOffset);
        view.layer.shadowRadius = ShadowRadius;
        view.layer.shadowOpacity = ShadowOpacity;

        view.tab.backgroundColor = displayContent.dismissButtonColor;
        view.tab.layer.masksToBounds = YES;
        view.tab.layer.cornerRadius = view.tab.frame.size.height/2;

        [view layoutSubviews];
    }

    return view;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    // Applies iPhone X inset spacing, otherwise no-op
    [self applyInsetSpacing];
    [self applyLayerRounding];

    // Limit absolute banner height to window height - padding
    self.heightConstraint = [NSLayoutConstraint constraintWithItem:self
                                                         attribute:NSLayoutAttributeHeight
                                                         relatedBy:NSLayoutRelationLessThanOrEqual
                                                            toItem:nil
                                                         attribute:NSLayoutAttributeNotAnAttribute
                                                        multiplier:1
                                                          constant:[UAUtils mainWindow].frame.size.height - DefaultBannerHeightPadding];

    self.heightConstraint.active = YES;
    [self layoutIfNeeded];
}

- (void)applyInsetSpacing {
    if (@available(iOS 11.0, *)) {
        UIWindow *window = [UAUtils mainWindow];

        self.topConstraint.constant = window.safeAreaInsets.top;
        self.contentTopConstraint.constant = window.safeAreaInsets.top ?: VerticalPaddingToSafeArea;

        self.bottomConstraint.constant = window.safeAreaInsets.bottom;
        self.contentBottomConstraint.constant = window.safeAreaInsets.bottom ?: VerticalPaddingToSafeArea;
        self.noButtonsContentBottomConstraint.constant = window.safeAreaInsets.bottom ?: VerticalPaddingToSafeArea;
    }

    [self layoutIfNeeded];
}

- (void)applyLayerRounding {
    NSUInteger bannerBorderRadius = self.displayContent.borderRadius;
    CAShapeLayer * maskLayer = [CAShapeLayer layer];
    maskLayer.path = [UIBezierPath bezierPathWithRoundedRect:self.containerView.bounds
                                           byRoundingCorners:(UIRectCorner)self.rounding
                                                 cornerRadii:(CGSize){bannerBorderRadius, bannerBorderRadius}].CGPath;

    self.containerView.layer.backgroundColor = [self.displayContent.backgroundColor CGColor];

    self.containerView.layer.mask = maskLayer;
}

- (void)setIsBeingTapped:(BOOL)isBeingTapped {
    _isBeingTapped = isBeingTapped;
    if (isBeingTapped) {
        self.alpha = BannerIsBeingTappedAlpha;
        return;
    }

    self.alpha = 1;
}

- (void)addBannerContentView:(UAInAppMessageBannerContentView *)bannerContentView {
    self.bannerContentView = bannerContentView;

    [self.bannerContentContainerView addSubview:bannerContentView];
    [UAInAppMessageUtils applyContainerConstraintsToContainer:self.bannerContentContainerView containedView:bannerContentView];

    [self.bannerContentContainerView layoutSubviews];
}

- (void)addButtonView:(UAInAppMessageButtonView *)buttonView {
    self.buttonView = buttonView;

    [self.buttonContainerView addSubview:buttonView];
    [UAInAppMessageUtils applyContainerConstraintsToContainer:self.buttonContainerView containedView:buttonView];

    [self.buttonContainerView layoutSubviews];
}

@end

NS_ASSUME_NONNULL_END
