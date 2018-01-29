/* Copyright 2018 Urban Airship and Contributors */

#import "UAInAppMessageButton+Internal.h"
#import "UAColorUtils+Internal.h"
#import "UAInAppMessageUtils+Internal.h"

CGFloat const ButtonIsBeingTappedAlpha = 0.7;
CGFloat const UAInAppMessageButtonMargin = 15;
CGFloat const UAInAppMessageFooterMargin = 0;

@interface UAInAppMessageButton ()
@property(nonatomic, strong) UAInAppMessageButtonInfo *buttonInfo;
@property(nonatomic, assign) UAInAppMessageButtonRounding rounding;
@property(nonatomic, assign) BOOL isFooter;

@end

@implementation UAInAppMessageButton

+ (instancetype)buttonWithButtonInfo:(UAInAppMessageButtonInfo *)buttonInfo
                            rounding:(UAInAppMessageButtonRounding)rounding {
return [[self alloc] initWithButtonInfo:buttonInfo
                               rounding:rounding];
}

+ (instancetype)footerButtonWithButtonInfo:(UAInAppMessageButtonInfo *)buttonInfo {
    return [[self alloc] initFooterWithButtonInfo:buttonInfo];
}


- (instancetype)initFooterWithButtonInfo:(UAInAppMessageButtonInfo *)buttonInfo {
    self = [super init];

    if (self) {
        self.buttonInfo = buttonInfo;
        self.rounding = 0;
        self.isFooter = true;
        [UAInAppMessageUtils applyButtonInfo:buttonInfo button:self buttonMargin:UAInAppMessageFooterMargin];

        // Apply rounding on layout subviews
        [self layoutSubviews];
    }

    return self;
}

- (instancetype)initWithButtonInfo:(UAInAppMessageButtonInfo *)buttonInfo
                          rounding:(UAInAppMessageButtonRounding)rounding {
    self = [super init];

    if (self) {
        self.buttonInfo = buttonInfo;
        self.rounding = rounding;
        [UAInAppMessageUtils applyButtonInfo:buttonInfo button:self buttonMargin:UAInAppMessageButtonMargin];

        // Apply rounding on layout subviews
        [self layoutSubviews];
    }

    return self;
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];

    if (self.isFooter) {
        if (highlighted) {
            self.titleLabel.textColor = [self.titleLabel.textColor colorWithAlphaComponent:ButtonIsBeingTappedAlpha];
        } else {
            self.titleLabel.textColor = [self.titleLabel.textColor colorWithAlphaComponent:1];
        }

        return;
    }

    if (highlighted) {
        self.backgroundColor = [self.backgroundColor colorWithAlphaComponent:ButtonIsBeingTappedAlpha];
    } else {
        self.backgroundColor = [self.backgroundColor colorWithAlphaComponent:1];
    }

}

- (void)layoutSubviews {
    [super layoutSubviews];

    if (!self.isFooter) {
        [self applyLayerRounding];
        [self applyBorder];
    }
}

-(void)applyLayerRounding {
    CGFloat radius = self.buttonInfo.borderRadius;

    CAShapeLayer * maskLayer = [CAShapeLayer layer];
    maskLayer.path = [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                           byRoundingCorners:(UIRectCorner)self.rounding
                                                 cornerRadii:(CGSize){radius, radius}].CGPath;
    self.layer.mask = maskLayer;


}

-(void)applyBorder {
    CGFloat radius = self.buttonInfo.borderRadius;
    CGPathRef borderPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                               byRoundingCorners:(UIRectCorner)self.rounding
                                                     cornerRadii:(CGSize){radius, radius}].CGPath;

    CAShapeLayer *borderLayer = [CAShapeLayer layer];
    borderLayer.frame = self.bounds;
    borderLayer.lineWidth = 2;
    borderLayer.fillColor = [[UIColor clearColor] CGColor];
    borderLayer.strokeColor = [self.buttonInfo.borderColor CGColor];
    borderLayer.path = borderPath;

    // Remove last applied shape layer
    for (CALayer *layer in self.layer.sublayers) {
        if ([layer isKindOfClass:[CAShapeLayer class]]) {
            [layer removeFromSuperlayer];
        }
    }

    [self.layer addSublayer:borderLayer];
}

@end
