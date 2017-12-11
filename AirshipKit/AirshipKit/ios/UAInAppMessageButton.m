/* Copyright 2017 Urban Airship and Contributors */

#import "UAInAppMessageButton+Internal.h"
#import "UAColorUtils+Internal.h"
#import "UAInAppMessageUtils+Internal.h"

CGFloat const ButtonIsBeingTappedAlpha = 0.7;

@interface UAInAppMessageButton ()
@property(nonatomic, strong) UAInAppMessageButtonInfo *buttonInfo;
@property(nonatomic, assign) UAInAppMessageButtonRounding rounding;
@end

@implementation UAInAppMessageButton

+ (instancetype)buttonWithButtonInfo:(UAInAppMessageButtonInfo *)buttonInfo
                            rounding:(UAInAppMessageButtonRounding)rounding {
return [[self alloc] initWithButtonInfo:buttonInfo
                               rounding:rounding];
}

- (instancetype)initWithButtonInfo:(UAInAppMessageButtonInfo *)buttonInfo
                          rounding:(UAInAppMessageButtonRounding)rounding {
    self = [super init];

    if (self) {
        self.buttonInfo = buttonInfo;
        self.rounding = rounding;
        [UAInAppMessageUtils applyButtonInfo:buttonInfo button:self];

        // Apply rounding on layout subviews
        [self layoutSubviews];
    }

    return self;
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];

    if (highlighted) {
        self.backgroundColor = [self.backgroundColor colorWithAlphaComponent:ButtonIsBeingTappedAlpha];
    } else {
        self.backgroundColor = [self.backgroundColor colorWithAlphaComponent:1];
    }

}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self applyLayerRounding];
}

-(void)applyLayerRounding {
    CGFloat radius = self.buttonInfo.borderRadius;

    CAShapeLayer * maskLayer = [CAShapeLayer layer];
    maskLayer.path = [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                           byRoundingCorners:(UIRectCorner)self.rounding
                                                 cornerRadii:(CGSize){radius, radius}].CGPath;

    self.layer.mask = maskLayer;
}

@end
