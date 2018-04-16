/* Copyright 2018 Urban Airship and Contributors */

#import "UAInAppMessageCloseButton+Internal.h"

CGFloat const XPaddingFromContainerTop = 16;
CGFloat const XHeight = 30;
CGFloat const XWidth = 30;
CGFloat const XInset = 10;
CGFloat const XThickness = 2;

CGFloat const CircleTransparency = 0.25;

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

    CGRect xFrame = CGRectInset(CGRectMake(self.bounds.origin.x, self.bounds.origin.y + XPaddingFromContainerTop, XWidth, XHeight), XInset, XInset);

    // Draw a semi-transparent white circle
    CGContextSetFillColorWithColor(context, [UIColor colorWithWhite:1 alpha:CircleTransparency].CGColor);

    CGRect circleRect = CGRectInset(CGRectMake(self.bounds.origin.x, self.bounds.origin.y + XPaddingFromContainerTop, XWidth, XHeight), 1, 1);
    CGContextFillEllipseInRect(context, circleRect);

    CGContextSetLineWidth(context, 0);
    CGContextSetStrokeColorWithColor(context, strokeColor.CGColor);
    CGContextStrokeEllipseInRect(context, circleRect);

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
    aPath.lineWidth = XThickness;
    bPath.lineWidth = XThickness;

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
