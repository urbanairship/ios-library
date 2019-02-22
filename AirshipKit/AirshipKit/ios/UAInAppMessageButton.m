/* Copyright Urban Airship and Contributors */

#import "UAInAppMessageButton+Internal.h"
#import "UAColorUtils+Internal.h"
#import "UAInAppMessageUtils+Internal.h"

CGFloat const ButtonIsBeingTappedAlpha = 0.7;
CGFloat const DefaultButtonMargin = 15;
CGFloat const DefaultFooterMargin = 0;
CGFloat const DefaultButtonBorderWidth = 2;


@interface UAInAppMessageButton ()
@property(nonatomic, strong) UAInAppMessageButtonInfo *buttonInfo;
@property(nonatomic, assign) UAInAppMessageButtonRounding rounding;
@property(nonatomic, assign) BOOL isFooter;

@end

@implementation UAInAppMessageButton

+ (instancetype)buttonWithButtonInfo:(UAInAppMessageButtonInfo *)buttonInfo
                               style:(UAInAppMessageButtonStyle *)style
                            rounding:(UAInAppMessageButtonRounding)rounding {
    return [[self alloc] initWithButtonInfo:buttonInfo
                                      style:style
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

        [UAInAppMessageUtils applyButtonInfo:buttonInfo style:nil button:self buttonMargin:DefaultFooterMargin];

        // Apply rounding on layout subviews
        [self layoutSubviews];
    }

    return self;
}

- (instancetype)initWithButtonInfo:(UAInAppMessageButtonInfo *)buttonInfo
                             style:(UAInAppMessageButtonStyle *)style
                          rounding:(UAInAppMessageButtonRounding)rounding {
    self = [super init];

    if (self) {
        self.buttonInfo = buttonInfo;
        self.rounding = rounding;
        self.style = style;

        // Style the buttons
        [UAInAppMessageUtils applyButtonInfo:buttonInfo
                                       style:style
                                      button:self
                                buttonMargin:DefaultButtonMargin];

        // Replace the style padding
        CGFloat top = style.buttonTextStyle.additionalPadding.top ? [style.buttonTextStyle.additionalPadding.top floatValue] : 0;
        CGFloat bottom = style.buttonTextStyle.additionalPadding.bottom ? [style.buttonTextStyle.additionalPadding.bottom floatValue] : 0;
        CGFloat trailing = style.buttonTextStyle.additionalPadding.trailing ? [style.buttonTextStyle.additionalPadding.trailing floatValue] : 0;
        CGFloat leading = style.buttonTextStyle.additionalPadding.leading ? [style.buttonTextStyle.additionalPadding.leading floatValue] : 0;

        [self setTitleEdgeInsets:UIEdgeInsetsMake(top, leading, bottom, trailing)];

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

        [self applyBorderOfWidth:self.style.borderWidth ? [self.style.borderWidth floatValue] :  DefaultButtonBorderWidth];
    }
}

-(void)applyLayerRounding {
    CGFloat radius = self.buttonInfo.borderRadiusPoints;

    CAShapeLayer * maskLayer = [CAShapeLayer layer];
    maskLayer.path = [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                           byRoundingCorners:(UIRectCorner)self.rounding
                                                 cornerRadii:(CGSize){radius, radius}].CGPath;
    self.layer.mask = maskLayer;


}

-(void)applyBorderOfWidth:(CGFloat)width {
    CGFloat radius = self.buttonInfo.borderRadiusPoints;
    CGPathRef borderPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                                 byRoundingCorners:(UIRectCorner)self.rounding
                                                       cornerRadii:(CGSize){radius, radius}].CGPath;

    CAShapeLayer *borderLayer = [CAShapeLayer layer];
    borderLayer.frame = self.bounds;
    borderLayer.lineWidth = width;
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

