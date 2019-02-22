/* Copyright Urban Airship and Contributors */

#import "UAirship.h"
#import "UAInAppMessageBannerView+Internal.h"
#import "UAInAppMessageBannerContentView+Internal.h"
#import "UAInAppMessageButtonView+Internal.h"
#import "UAInAppMessageUtils+Internal.h"
#import "UAInAppMessageBannerDisplayContent+Internal.h"
#import "UAColorUtils+Internal.h"
#import "UAUtils+Internal.h"
#import "UAViewUtils+Internal.h"

#import "UAInAppMessageBannerDisplayContent+Internal.h"

NS_ASSUME_NONNULL_BEGIN

/*
 * Default view padding
 */
CGFloat const BannerDefaultPadding = 16.0;

// UAInAppMessageBannerContentView nib name
NSString *const UAInAppMessageBannerViewNibName = @"UAInAppMessageBannerView";
CGFloat const VerticalPaddingToSafeArea = 20;
CGFloat const BannerIsBeingTappedAlpha = 0.7;
CGFloat const DefaultBannerHeightPadding = 60;

CGFloat const ShadowOffset = 2.0;
CGFloat const ShadowRadius = 4.0;
CGFloat const ShadowOpacity = 0.5;

@interface UAInAppMessageBannerView ()

@property (nonatomic, strong) UAInAppMessageBannerDisplayContent *displayContent;

@property (nonatomic, strong) IBOutlet UIView *bannerContentContainerView;
@property (nonatomic, strong) IBOutlet UIView *buttonContainerView;
@property (strong, nonatomic) IBOutlet UIView *nubCover;

@property (nonatomic, strong) UAInAppMessageBannerContentView *bannerContentView;
@property (nonatomic, strong) UAInAppMessageButtonView *buttonView;
@property (strong, nonatomic) IBOutlet UIView *tab;

@property (nonatomic, assign) UAInAppMessageButtonRounding rounding;

@property (strong, nonatomic) NSLayoutConstraint *absoluteHeightConstraint;

@end

@implementation UAInAppMessageBannerView

+ (instancetype)bannerMessageViewWithDisplayContent:(UAInAppMessageBannerDisplayContent *)displayContent
                                  bannerContentView:(UAInAppMessageBannerContentView *)contentView
                                         buttonView:(nullable UAInAppMessageButtonView *)buttonView
                                              style:(UAInAppMessageBannerStyle *)style {

    NSString *nibName = UAInAppMessageBannerViewNibName;
    NSBundle *bundle = [UAirship resources];

    // Top and bottom banner views are firstObject and lastObject, respectively.
    UAInAppMessageBannerView *view;
    switch (displayContent.placement) {
        case UAInAppMessageBannerPlacementTop:
            view = [[bundle loadNibNamed:nibName owner:nil options:nil] firstObject];
            break;
        case UAInAppMessageBannerPlacementBottom:
            view = [[bundle loadNibNamed:nibName owner:nil options:nil] lastObject];
            break;
    }

    [view configureBannerViewWithDisplayContent:displayContent bannerContentView:contentView buttonView:buttonView style:style];

    return view;
}

- (void)configureBannerViewWithDisplayContent:(UAInAppMessageBannerDisplayContent *)displayContent
                            bannerContentView:(UAInAppMessageBannerContentView *)contentView
                                   buttonView:(nullable UAInAppMessageButtonView *)buttonView
                                        style:(UAInAppMessageBannerStyle *)style {

    CGFloat shadowOffset;

    switch (displayContent.placement) {
        case UAInAppMessageBannerPlacementTop:
            shadowOffset = ShadowOffset;
            self.rounding = UIRectCornerBottomLeft | UIRectCornerBottomRight;
            break;
        case UAInAppMessageBannerPlacementBottom:
            shadowOffset = -ShadowOffset;
            self.rounding = UIRectCornerTopLeft | UIRectCornerTopRight;
            break;
    }

    [self addBannerContentView:contentView];

    if (buttonView) {
        [self addButtonView:buttonView];
    } else {
        [self.buttonContainerView removeFromSuperview];
    }

    self.displayContent = displayContent;
    // The layer color is set to background color to preserve rounding and shadow
    self.backgroundColor = [UIColor clearColor];
    self.nubCover.backgroundColor = displayContent.backgroundColor;

    self.layer.shadowOffset = CGSizeMake(0, shadowOffset);
    self.layer.shadowRadius = ShadowRadius;

    self.translatesAutoresizingMaskIntoConstraints = NO;

    self.layer.shadowOffset = CGSizeMake(shadowOffset/2, shadowOffset);
    self.layer.shadowRadius = ShadowRadius;
    self.layer.shadowOpacity = ShadowOpacity;

    self.tab.backgroundColor = displayContent.dismissButtonColor;
    self.tab.layer.masksToBounds = YES;
    self.tab.layer.cornerRadius = self.tab.frame.size.height/2;

    [self layoutSubviews];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    // Limit absolute banner height to window height - padding
    self.absoluteHeightConstraint.active = NO;
    self.absoluteHeightConstraint = [NSLayoutConstraint constraintWithItem:self
                                                                 attribute:NSLayoutAttributeHeight
                                                                 relatedBy:NSLayoutRelationLessThanOrEqual
                                                                    toItem:nil
                                                                 attribute:NSLayoutAttributeNotAnAttribute
                                                                multiplier:1
                                                                  constant:[UAUtils mainWindow].frame.size.height - DefaultBannerHeightPadding];

    self.absoluteHeightConstraint.active = YES;

    [self applyLayerRounding];

    [self layoutIfNeeded];
}

- (void)applyLayerRounding {
    CGFloat bannerBorderRadius = self.displayContent.borderRadiusPoints;
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
    [UAViewUtils applyContainerConstraintsToContainer:self.bannerContentContainerView containedView:bannerContentView];

    [self.bannerContentContainerView layoutSubviews];
}

- (void)addButtonView:(UAInAppMessageButtonView *)buttonView {
    self.buttonView = buttonView;

    [self.buttonContainerView addSubview:buttonView];
    [UAViewUtils applyContainerConstraintsToContainer:self.buttonContainerView containedView:buttonView];

    [self.buttonContainerView layoutSubviews];
}

@end

NS_ASSUME_NONNULL_END

