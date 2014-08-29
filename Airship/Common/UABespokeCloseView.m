/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "UABespokeCloseView.h"

@implementation UABespokeCloseView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.opaque = NO; //peek through around the circle!
    }
    return self;
}

- (void)drawRect:(CGRect)rect {

    UIColor *strokeColor = [UIColor whiteColor];

    // Draw a white circle
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);

    NSInteger circleInset = 5;
    CGRect circleRect = CGRectInset(self.bounds, circleInset, circleInset);
    CGContextFillEllipseInRect(context, circleRect);

    CGContextSetLineWidth(context, 2);
    CGContextSetStrokeColorWithColor(context, strokeColor.CGColor);
    CGContextStrokeEllipseInRect(context, circleRect);

    // The X gets to be a little smaller than the circle
    NSInteger xInset = 7;

    CGRect xFrame = CGRectInset(circleRect, xInset, xInset);

    // CGRect gymnastics
    UIBezierPath *aPath = [UIBezierPath bezierPath];
    [aPath moveToPoint:xFrame.origin];//minx, miny
    [aPath addLineToPoint:CGPointMake(CGRectGetMaxX(xFrame), CGRectGetMaxY(xFrame))];

    UIBezierPath *bPath = [UIBezierPath bezierPath];
    [bPath moveToPoint:CGPointMake(CGRectGetMaxX(xFrame), CGRectGetMinY(xFrame))];
    [bPath addLineToPoint:CGPointMake(CGRectGetMinX(xFrame), CGRectGetMaxY(xFrame))];

    // Set the render colors.
    [strokeColor setStroke];

    // Adjust the drawing options as needed.
    aPath.lineWidth = 3;
    bPath.lineWidth = 3;

    // Line cap style
    aPath.lineCapStyle = kCGLineCapButt;
    bPath.lineCapStyle = kCGLineCapButt;

    // Draw both strokes
    [aPath stroke];
    [bPath stroke];
}

@end
