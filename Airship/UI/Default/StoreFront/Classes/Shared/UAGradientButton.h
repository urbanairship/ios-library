//
//  ButtonGradientView.h
//  Custom Alert View
//
//  Created by jeff on 5/17/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreGraphics/CoreGraphics.h>

@interface UAGradientButton : UIButton
{
    // These two arrays define the gradient that will be used
    // when the button is in UIControlStateNormal
    NSArray *normalGradientColors;      // Colors
    NSArray *normalGradientLocations;   // Relative locations
    
    // These variables define the stroke color and weight 
    // when the button is in UIControlStateNormal
    UIColor *normalStrokeColor;
    CGFloat normalStrokeWeight;

    // These two arrays define the gradient that will be used
    // when the button is in UIControlStateHighlighted
    NSArray *highlightGradientColors;      // Colors
    NSArray *highlightGradientLocations;   // Relative locations
    
    // These variables define the stroke color and weight
    // when the button is in UIControlStateHighlighted
    UIColor *highlightStrokeColor;
    CGFloat highlightStrokeWeight;
    
    // These two arrays define the gradient that will be used
    // when the button is in UIControlStateDisabled
    NSArray *disabledGradientColors;      // Colors
    NSArray *disabledGradientLocations;   // Relative locations
    
    // These variables define the stroke color and weight
    // when the button is in UIControlStateDisabled
    UIColor *disabledStrokeColor;
    CGFloat disabledStrokeWeight;

    // This defines the corner radius of the button
    CGFloat cornerRadius;

    @private
    CGGradientRef normalGradient;
    CGGradientRef highlightGradient;
    CGGradientRef disabledGradient;
}

@property (nonatomic, retain) NSArray *normalGradientColors;
@property (nonatomic, retain) NSArray *normalGradientLocations;
@property (nonatomic, retain) UIColor *normalStrokeColor;
@property (nonatomic)         CGFloat normalStrokeWeight;
@property (nonatomic, retain) NSArray *highlightGradientColors;
@property (nonatomic, retain) NSArray *highlightGradientLocations;
@property (nonatomic, retain) UIColor *highlightStrokeColor;
@property (nonatomic)         CGFloat highlightStrokeWeight;
@property (nonatomic, retain) NSArray *disabledGradientColors;
@property (nonatomic, retain) NSArray *disabledGradientLocations;
@property (nonatomic, retain) UIColor *disabledStrokeColor;
@property (nonatomic)         CGFloat disabledStrokeWeight;
@property (nonatomic) CGFloat cornerRadius;

- (void) useStyleFromColor:(UIColor *)color;
- (void) usePurpleGameMinderStyle;
- (void) useAlertStyle;
- (void) useRedDeleteStyle;
- (void) useWhiteStyle;
- (void) useBlackStyle;
- (void) useMyBlackStyle;
- (void) useMyInvertedBlackStyle;
- (void) useWhiteActionSheetStyle;
- (void) useBlackActionSheetStyle;
- (void) useSimpleOrangeStyle;
- (void) useGreenConfirmStyle;
- (void) useBlueStyle;

@end
