//
//  UICloseView.m
//  InboxSampleLib
//
//  Created by Jeff Towle on 10/3/13.
//
//

#import "UABespokeCloseView.h"

@implementation UABespokeCloseView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        self.opaque = NO;
    }
    return self;
}


// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code

    // Create an oval shape to draw.

    //an iOS7y blue
    UIColor *funBlue = [UIColor colorWithRed:0.062 green:0.368 blue:0.984 alpha:1.0];

    //105efb

    CGContextRef context = UIGraphicsGetCurrentContext();
//
//    UIColor *redColor = [UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:0.5];
//
    CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
    //CGContextFillRect(context, self.bounds);
    CGContextFillEllipseInRect(context, self.bounds);




    NSInteger inset = 5;

    UIBezierPath *aPath = [UIBezierPath bezierPath];
    [aPath moveToPoint:CGPointMake(inset, inset)];
    [aPath addLineToPoint:CGPointMake(self.bounds.size.width-inset,self.bounds.size.height-inset)];

    UIBezierPath *bPath = [UIBezierPath bezierPath];
    [bPath moveToPoint:CGPointMake(self.bounds.size.width-inset, 0.0+inset)];
    [bPath addLineToPoint:CGPointMake(0.0+inset, self.bounds.size.height-inset)];

//    // Draw the lines.
//    [aPath addLineToPoint:CGPointMake(20.0, 40.0)];
//    [aPath addLineToPoint:CGPointMake(16.0, 30.0)];
//    [aPath addLineToPoint:CGPointMake(40.0, 30.0)];
//    [aPath addLineToPoint:CGPointMake(0.0, 40.0)];


    // Set the render colors.
    [funBlue setStroke];

    CGContextRef aRef = UIGraphicsGetCurrentContext();

    // If you have content to draw after the shape,
    // save the current state before changing the transform.
    //CGContextSaveGState(aRef);

    // Adjust the view's origin temporarily. The oval is
    // now drawn relative to the new origin point.
    CGContextTranslateCTM(aRef, 0, 0);

    // Adjust the drawing options as needed.
    aPath.lineWidth = 2;
    bPath.lineWidth = 2;

    aPath.lineCapStyle = kCGLineCapButt;
    bPath.lineCapStyle = kCGLineCapButt;

    // Fill the path before stroking it so that the fill
    // color does not obscure the stroked line.

    [aPath stroke];
    [bPath stroke];
    
    // Restore the graphics state before drawing any other content.
    //CGContextRestoreGState(aRef);
}


@end
