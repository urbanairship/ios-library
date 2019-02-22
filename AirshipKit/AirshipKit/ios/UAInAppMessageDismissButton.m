/* Copyright Urban Airship and Contributors */

#import "UAInAppMessageDismissButton+Internal.h"
#import "UAInAppMessageUtils+Internal.h"

// Close button defaults to X if icon image is unspecified
CGFloat const CloseButtonIconHeight = 30;
CGFloat const CloseButtonIconWidth = 30;

CGFloat const XPaddingFromContainerTop = 16;
CGFloat const XInset = 10;
CGFloat const XThickness = 2;

CGFloat const CircleTransparency = 0.25;

@interface UAInAppMessageDismissButton()
@property(nonatomic, strong) UIImageView *iconView;
@end

@implementation UAInAppMessageDismissButton

+ (instancetype)closeButtonWithIconImageName:(nullable NSString *)imageName color:(nullable UIColor *)color {
    return [[self alloc] initWithIconImageName:imageName color:color];
}

- (instancetype)initWithIconImageName:(NSString *)iconImageName color:(UIColor *)color {
    self = [super init];

    if (self) {
        self.userInteractionEnabled = YES;

        self.accessibilityLabel = @"Dismiss";

        // Default to dark gray if provided color is nil
        self.dismissButtonColor = color ?: [UIColor darkGrayColor];
        self.closeIcon = [UIImage imageNamed:iconImageName];
        if (self.closeIcon) {
            UIImageView *iconView = [[UIImageView alloc] init];
            [self addSubview:iconView];
            // Apply close button constraints to icon view
            [UAInAppMessageUtils applyCloseButtonImageConstraintsToContainer:self closeButtonImageView:iconView];
            iconView.image = self.closeIcon;
            iconView.userInteractionEnabled = NO;
            self.iconView.exclusiveTouch = NO;
        }
    }

    return self;
}

- (void)drawRect:(CGRect)rect {
    // If no dismiss button image is provided, draw the default close button
    if (!self.closeIcon) {
        UIColor *strokeColor = self.dismissButtonColor;

        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(context, [UIColor clearColor].CGColor);

        CGRect xFrame = CGRectInset(CGRectMake(self.bounds.origin.x, self.bounds.origin.y + XPaddingFromContainerTop, CloseButtonIconWidth, CloseButtonIconHeight), XInset, XInset);

        // Draw a semi-transparent white circle
        CGContextSetFillColorWithColor(context, [UIColor colorWithWhite:1 alpha:CircleTransparency].CGColor);

        CGRect circleRect = CGRectInset(CGRectMake(self.bounds.origin.x, self.bounds.origin.y + XPaddingFromContainerTop, CloseButtonIconWidth, CloseButtonIconHeight), 1, 1);
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
}

-(void)layoutSubviews {
    self.backgroundColor = [UIColor clearColor];
}

@end
