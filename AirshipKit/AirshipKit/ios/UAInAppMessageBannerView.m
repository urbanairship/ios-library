/* Copyright 2017 Urban Airship and Contributors */

#import "UAirship.h"
#import "UAInAppMessageBannerView+Internal.h"
#import "UAInAppMessageBannerContentView+Internal.h"
#import "UAInAppMessageButtonView+Internal.h"
#import "UAInAppMessageUtils+Internal.h"
#import "UAInAppMessageBannerDisplayContent+Internal.h"
#import "UAColorUtils+Internal.h"

#import "UAInAppMessageBannerDisplayContent+Internal.h"

// UAInAppMessageBannerContentView nib name
NSString *const UAInAppMessageBannerViewNibName = @"UAInAppMessageBannerView";
CGFloat const BannerIsBeingTappedAlpha = 0.7;
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

@end

@implementation UAInAppMessageBannerView

+ (instancetype)bannerMessageViewWithDisplayContent:(UAInAppMessageBannerDisplayContent *)displayContent
                                  bannerContentView:(UAInAppMessageBannerContentView *)contentView
                                         buttonView:(UAInAppMessageButtonView *)buttonView {

    return [[UAInAppMessageBannerView alloc] initBannerViewWithDisplayContent:displayContent
                                                            bannerContentView:contentView
                                                                   buttonView:buttonView];
}

- (instancetype)initBannerViewWithDisplayContent:(UAInAppMessageBannerDisplayContent *)displayContent
                               bannerContentView:(UAInAppMessageBannerContentView *)contentView
                                      buttonView:(UAInAppMessageButtonView *)buttonView {
    NSString *nibName = UAInAppMessageBannerViewNibName;
    NSBundle *bundle = [UAirship resources];
    CGFloat shadowOffset;

    NSString *placement = displayContent.placement;
    // Top and bottom banner views are firstObject and lastObject, respectively.
    if ([placement isEqualToString:UAInAppMessageBannerPlacementTop]) {
        self = [[bundle loadNibNamed:nibName owner:self options:nil] firstObject];
        shadowOffset = ShadowOffset;
        self.rounding = UIRectCornerBottomLeft | UIRectCornerBottomRight;
    } else if ([placement isEqualToString:UAInAppMessageBannerPlacementBottom]) {
        self = [[bundle loadNibNamed:nibName owner:self options:nil] lastObject];
        shadowOffset = -ShadowOffset;
        self.rounding = UIRectCornerTopLeft | UIRectCornerTopRight;
    } else {
        UA_LWARN(@"Invalid placement for banner view: %@", placement);
        return nil;
    }

    if (self) {
        [self addBannerContentView:contentView];
        [self addButtonView:buttonView];

        self.displayContent = displayContent;
        // The layer color is set to background color to preserve rounding and shadow
        self.backgroundColor = [UIColor clearColor];

        self.layer.shadowOffset = CGSizeMake(0, shadowOffset);
        self.layer.shadowRadius = ShadowRadius;
        
        self.translatesAutoresizingMaskIntoConstraints = NO;

        self.layer.shadowOffset = CGSizeMake(shadowOffset/2, shadowOffset);
        self.layer.shadowRadius = ShadowRadius;
        self.layer.shadowOpacity = ShadowOpacity;

        self.tab.backgroundColor = [UAColorUtils colorWithHexString:displayContent.dismissButtonColor];
        self.tab.layer.masksToBounds = YES;
        self.tab.layer.cornerRadius = self.tab.frame.size.height/2;

        [self layoutSubviews];
    }

    return self;
}

-(void)layoutSubviews {
    [super layoutSubviews];
    [self applyLayerRounding];
}

-(void)applyLayerRounding {
    NSUInteger bannerBorderRadius = self.displayContent.borderRadius;
    CAShapeLayer * maskLayer = [CAShapeLayer layer];
    maskLayer.path = [UIBezierPath bezierPathWithRoundedRect:self.containerView.bounds
                                           byRoundingCorners:(UIRectCorner)self.rounding
                                                 cornerRadii:(CGSize){bannerBorderRadius, bannerBorderRadius}].CGPath;

    self.containerView.layer.backgroundColor = [[UAColorUtils colorWithHexString:self.displayContent.backgroundColor] CGColor];

    self.containerView.layer.mask = maskLayer;
}

-(void)setIsBeingTapped:(BOOL)isBeingTapped {
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
