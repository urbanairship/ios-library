/* Copyright 2018 Urban Airship and Contributors */

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

    //NSInteger xInset = 10;
    CGRect xFrame = CGRectInset(CGRectMake(self.bounds.origin.x, self.bounds.origin.y + 16, 30, 30), 10, 10);

    // Draw a white circle
    CGContextSetFillColorWithColor(context, [UIColor colorWithWhite:1 alpha:0.25].CGColor);

    //NSInteger circleInset = 5;
    CGRect circleRect = CGRectInset(CGRectMake(self.bounds.origin.x, self.bounds.origin.y + 16, 30, 30), 1, 1);
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
    aPath.lineWidth = 2;
    bPath.lineWidth = 2;

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
