/* Copyright 2017 Urban Airship and Contributors */

#import "UAInAppMessageCloseButton+Internal.h"

@implementation UAInAppMessageCloseButton

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        self.dismissButtonColor = [UIColor darkGrayColor];
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    UIColor *strokeColor = self.dismissButtonColor;

    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [UIColor clearColor].CGColor);
    NSInteger xInset = 1;

    CGRect xFrame = CGRectInset(self.bounds, xInset, xInset);

    // Draw X
    UIBezierPath *aPath = [UIBezierPath bezierPath];
    [aPath moveToPoint:xFrame.origin];
    [aPath addLineToPoint:CGPointMake(CGRectGetMaxX(xFrame), CGRectGetMaxY(xFrame))];

    UIBezierPath *bPath = [UIBezierPath bezierPath];
    [bPath moveToPoint:CGPointMake(CGRectGetMaxX(xFrame), CGRectGetMinY(xFrame))];
    [bPath addLineToPoint:CGPointMake(CGRectGetMinX(xFrame), CGRectGetMaxY(xFrame))];

    // Set the render colors.
    [strokeColor setStroke];

    // Adjust the drawing options as needed.
    aPath.lineWidth = 2.5;
    bPath.lineWidth = 2.5;

    // Line cap style
    aPath.lineCapStyle = kCGLineCapButt;
    bPath.lineCapStyle = kCGLineCapButt;

    // Draw both strokes
    [aPath stroke];
    [bPath stroke];
}

-(void)layoutSubviews {
    self.backgroundColor = [UIColor clearColor];
}

@end
