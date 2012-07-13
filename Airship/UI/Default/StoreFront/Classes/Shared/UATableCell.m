/*
 Copyright 2009-2011 Urban Airship Inc. All rights reserved.

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

#import "UATableCell.h"
#import "UAirship.h"
#import "UAStoreFrontUI.h"

@interface UATableCell ()
- (void)addGradientWithTopColor:(UIColor *)topColor bottomColor:(UIColor *)bottomColor;
@property (nonatomic, retain) CAGradientLayer *gradientLayer;
@end

@implementation UATableCell

@synthesize isOdd;
@synthesize gradientLayer;

-(void)dealloc {
    [super dealloc];
}


- (id)initWithStyle:(UITableViewCellStyle)style  reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle: style reuseIdentifier: reuseIdentifier]) {
        self.isOdd = NO;
    }
    return self;
}

- (void)setIsOdd:(BOOL)odd {
    isOdd = odd;

    if (isOdd) {
        self.backgroundColor = [UAStoreFrontUI shared].cellOddBackgroundColor;
        [self addGradientWithTopColor:[UAStoreFrontUI shared].cellOddGradientTopColor 
                          bottomColor:[UAStoreFrontUI shared].cellOddGradientBottomColor];
    } else {
        self.backgroundColor = [UAStoreFrontUI shared].cellEvenBackgroundColor;
        [self addGradientWithTopColor:[UAStoreFrontUI shared].cellEvenGradientTopColor 
                          bottomColor:[UAStoreFrontUI shared].cellEvenGradientBottomColor];
    }

}

- (void)addGradientWithTopColor:(UIColor *)topColor bottomColor:(UIColor *)bottomColor {
    // Do nothing if both colors are nil
    if (topColor == nil && bottomColor == nil) return;

    // If just one color is nil, use clear color for that color
    if (topColor == nil) topColor = [UIColor clearColor];
    if (bottomColor == nil) bottomColor = [UIColor clearColor];
    
    CAGradientLayer *gradient   = [CAGradientLayer layer];    
    gradient.colors = [NSArray arrayWithObjects:(id)[topColor CGColor], (id)[bottomColor CGColor], nil];
    self.gradientLayer = gradient;
}

- (void)setGradientLayer:(CAGradientLayer *)aGradientLayer {
    if (gradientLayer != nil) {
        [gradientLayer removeFromSuperlayer];
    }
    
    aGradientLayer.frame = self.bounds;

    if (self.backgroundView == nil) {
        // If we don't already have a backgroundView, add a clear one to put our gradient on.
        // Putting the gradient on the backgroundView assures that the selection state for the cell will
        // display over the gradient.
        UIView *aBackgroundView = [[UIView alloc] initWithFrame:self.bounds];
        aBackgroundView.opaque = NO;
        self.backgroundView = aBackgroundView;
        [aBackgroundView release];
    }

    [self.backgroundView.layer insertSublayer:aGradientLayer atIndex:0];
    gradientLayer = aGradientLayer;
}

- (void)prepareForReuse {
    self.gradientLayer = nil;
    self.backgroundView = nil;
    [super prepareForReuse];
}

/*
- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    CGContextRef context = UIGraphicsGetCurrentContext();

    //Background
    CGRect drawRect = CGRectMake(rect.origin.x, rect.origin.y,
                                 rect.size.width, rect.size.height);

    if(self.isOdd) {
        BG_RGBA(255.0f, 255.0f, 255.0f, 1.0f);
    } else {
        BG_RGBA(240.0f, 242.0f, 243.0f, 1.0f);
    }
    CGContextFillRect(context, drawRect);

    //Highlight
    BG_RGBA(255.0f, 255.0f, 255.f, 1.0f);
    CGRect highlight = CGRectMake(rect.origin.x, rect.origin.y,
                                  rect.size.width , rect.origin.y+1);
    CGContextFillRect(context, highlight);

    //Lowlight
    BG_RGBA(230.0f, 230.0f, 230.0f, 1.0f);
    CGRect lowlight = CGRectMake(rect.origin.x, rect.size.height-1 ,
                                 rect.size.width , rect.size.height);
    CGContextFillRect(context, lowlight);
}*/

@end
