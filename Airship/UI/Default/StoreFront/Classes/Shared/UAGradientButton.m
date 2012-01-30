//
//  ButtonGradientView.m
//  Custom Alert View
//
//  Created by jeff on 5/17/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "UAGradientButton.h"
#import "UIColor-Expanded.h"

@interface UAGradientButton ()
@property (nonatomic) CGGradientRef normalGradient;
@property (nonatomic) CGGradientRef highlightGradient;
@property (nonatomic) CGGradientRef disabledGradient;
- (void) hesitateUpdate; // Used to catch and fix problem where quick taps don't get updated back to normal state
@end

#pragma mark -

@implementation UAGradientButton

@synthesize normalGradientColors, normalGradientLocations;
@synthesize normalStrokeColor, normalStrokeWeight;
@synthesize highlightGradientColors, highlightGradientLocations;
@synthesize highlightStrokeColor, highlightStrokeWeight;
@synthesize disabledGradientColors, disabledGradientLocations;
@synthesize disabledStrokeColor, disabledStrokeWeight;
@synthesize cornerRadius;
@synthesize normalGradient, highlightGradient, disabledGradient;

#pragma mark -

- (CGGradientRef) normalGradient
{
    if (normalGradient == NULL)
    {
        NSUInteger locCount = [normalGradientLocations count];
        CGFloat locations[locCount];
        for (NSUInteger i = 0; i < [normalGradientLocations count]; i++)
        {
            NSNumber *location = [normalGradientLocations objectAtIndex:i];
            locations[i] = [location floatValue];
        }
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();

        normalGradient = CGGradientCreateWithColors(space, (CFArrayRef)normalGradientColors, locations);
        CGColorSpaceRelease(space);
    }
    return normalGradient;
}

- (void) setNormalGradient:(CGGradientRef)value
{
    if (normalGradient != NULL)
    {
        CGGradientRelease(normalGradient);
    }

    normalGradient = value;
}

- (CGGradientRef) highlightGradient
{
    if (highlightGradient == NULL)
    {
        CGFloat locations[[highlightGradientLocations count]];
        for (NSUInteger i = 0; i < [highlightGradientLocations count]; i++)
        {
            NSNumber *location = [highlightGradientLocations objectAtIndex:i];
            locations[i] = [location floatValue];
        }
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();

        highlightGradient = CGGradientCreateWithColors(space, (CFArrayRef)highlightGradientColors, locations);
        CGColorSpaceRelease(space);
    }
    return highlightGradient;
}

- (void) setHighlightGradient:(CGGradientRef)value
{
    if (highlightGradient != NULL)
    {
        CGGradientRelease(highlightGradient);
    }

    highlightGradient = value;
}

- (CGGradientRef) disabledGradient
{
    if (disabledGradient == NULL)
    {
        CGFloat locations[[disabledGradientLocations count]];
        for (NSUInteger i = 0; i < [disabledGradientLocations count]; i++)
        {
            NSNumber *location = [disabledGradientLocations objectAtIndex:i];
            locations[i] = [location floatValue];
        }
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        
        disabledGradient = CGGradientCreateWithColors(space, (CFArrayRef)disabledGradientColors, locations);
        CGColorSpaceRelease(space);
    }
    return disabledGradient;
}

- (void) setDisabledGradient:(CGGradientRef)value
{
    if (disabledGradient != NULL)
    {
        CGGradientRelease(disabledGradient);
    }
    
    disabledGradient = value;
}

- (void) setNormalGradientColors:(NSArray *)value
{
    [normalGradientColors release];
    normalGradientColors = [value retain];
    self.normalGradient = NULL;
}

- (void) setNormalGradientLocations:(NSArray *)value
{
    [normalGradientLocations release];
    normalGradientLocations = [value retain];
    self.normalGradient = NULL;
}

- (void) setHighlightGradientColors:(NSArray *)value
{
    [highlightGradientColors release];
    highlightGradientColors = [value retain];
    self.highlightGradient = NULL;
}

- (void) setHighlightGradientLocations:(NSArray *)value
{
    [highlightGradientLocations release];
    highlightGradientLocations = [value retain];
    self.highlightGradient = NULL;
}

- (void) setDisabledGradientColors:(NSArray *)value
{
    [disabledGradientColors release];
    disabledGradientColors = [value retain];
    self.disabledGradient = NULL;
}

- (void) setDisabledGradientLocations:(NSArray *)value
{
    [disabledGradientLocations release];
    disabledGradientLocations = [value retain];
    self.disabledGradient = NULL;
}

#pragma mark -
- (id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        [self setOpaque:NO];
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}
#pragma mark -
#pragma mark Appearances
- (void) usePurpleGameMinderStyle
{
    // Set up the appearance for UIControlStateNormal
    
    NSMutableArray *colors = [NSMutableArray arrayWithCapacity:5];

    UIColor *color1 = [UIColor colorWithRed:0.3294f green:0.1451f blue:0.5059f alpha:1.0f];
    [colors addObject:(id)[color1 CGColor]];
    
    UIColor *color2 = [UIColor colorWithRed:0.6314f green:0.4941f blue:0.7333f alpha:1.0];
    [colors addObject:(id)[color2 CGColor]];
    
    UIColor *color3 = [UIColor colorWithRed:0.4000f  green:0.1765f blue:0.5686f alpha:1.0];
    [colors addObject:(id)[color3 CGColor]];
    
    UIColor *color4 = [UIColor colorWithRed:0.2392f  green:0.1059f blue:0.4314f alpha:1.0];
    [colors addObject:(id)[color4 CGColor]];
    
    NSArray *locations = [NSArray arrayWithObjects:
                          [NSNumber numberWithFloat:0.0f],
                          [NSNumber numberWithFloat:1.0f],
                          [NSNumber numberWithFloat:0.582f],
                          [NSNumber numberWithFloat:0.418f],
                          [NSNumber numberWithFloat:0.346f],
                          nil];
    
    self.normalGradientColors = colors;
    self.normalGradientLocations = locations;
    
    [self setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    
    // Set up the appearance for UIControlStateHighlighted
    
    self.highlightGradientColors = colors;
    self.highlightGradientLocations = [NSArray arrayWithObjects:
                                       [NSNumber numberWithFloat:0.0f],
                                       [NSNumber numberWithFloat:1.0f],
                                       [NSNumber numberWithFloat:0.715f],
                                       [NSNumber numberWithFloat:0.513f],
                                       [NSNumber numberWithFloat:0.445f],
                                       nil];
    
    [self setTitleColor:[UIColor lightGrayColor] forState:UIControlStateHighlighted];
    
    // Set up the appearance for UIControlStateDisabled
    
    NSMutableArray *disabledColors = [NSMutableArray arrayWithCapacity:5];
        
    CGFloat hue;
    CGFloat saturation;
    CGFloat brightness;
    
    [UIColor red:[color1 red] green:[color1 green] blue:[color1 blue] toHue:&hue saturation:&saturation brightness:&brightness];
    [disabledColors addObject:(id)[[UIColor colorWithHue:hue saturation:(saturation/3.0) brightness:brightness+((1.0-brightness)/2.0) alpha:1.0] CGColor]];
    
    [UIColor red:[color2 red] green:[color2 green] blue:[color2 blue] toHue:&hue saturation:&saturation brightness:&brightness];
    [disabledColors addObject:(id)[[UIColor colorWithHue:hue saturation:(saturation/3.0) brightness:brightness+((1.0-brightness)/2.0) alpha:1.0] CGColor]];
    
    [UIColor red:[color3 red] green:[color3 green] blue:[color3 blue] toHue:&hue saturation:&saturation brightness:&brightness];
    [disabledColors addObject:(id)[[UIColor colorWithHue:hue saturation:(saturation/3.0) brightness:brightness+((1.0-brightness)/2.0) alpha:1.0] CGColor]];
    
    [UIColor red:[color4 red] green:[color4 green] blue:[color4 blue] toHue:&hue saturation:&saturation brightness:&brightness];
    [disabledColors addObject:(id)[[UIColor colorWithHue:hue saturation:(saturation/3.0) brightness:brightness+((1.0-brightness)/2.0) alpha:1.0] CGColor]];
    
    self.disabledGradientColors = disabledColors;
    self.disabledGradientLocations = locations;
    
    [self setTitleColor:[UIColor whiteColor] forState:UIControlStateDisabled];
    
    [UIColor 
     red:[self.normalStrokeColor red] green:[self.normalStrokeColor green] blue:[self.normalStrokeColor blue] 
     toHue:&hue saturation:&saturation brightness:&brightness
    ];
    
    self.disabledStrokeColor = [UIColor colorWithHue:hue saturation:(saturation/3.0) brightness:brightness+((1.0-brightness)/2.0) alpha:1.0];
    
    self.cornerRadius = 9.f;
}

- (void) useAlertStyle
{
    // Oddly enough, if I create the color array using arrayWithObjects:, it
    // doesn't work - the gradient comes back NULL
    NSMutableArray *colors = [NSMutableArray arrayWithCapacity:3];
    UIColor *color = [UIColor colorWithRed:0.283f green:0.32f blue:0.414f alpha:1.0f];

    [colors addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.82f green:0.834f blue:0.87f alpha:1.0f];
    [colors addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.186f green:0.223f blue:0.326f alpha:1.0f];
    [colors addObject:(id)[color CGColor]];
    self.normalGradientColors = colors;
    self.normalGradientLocations = [NSArray arrayWithObjects:
                                    [NSNumber numberWithFloat:0.0f],
                                    [NSNumber numberWithFloat:1.0f],
                                    [NSNumber numberWithFloat:0.483f],
                                    nil];

    NSMutableArray *colors2 = [NSMutableArray arrayWithCapacity:4];
    color = [UIColor colorWithRed:0.0 green:0.0f blue:0.0f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.656f green:0.683f blue:0.713f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.137f green:0.155f blue:0.208f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.237f green:0.257f blue:0.305f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    self.highlightGradientColors = colors2;
    self.highlightGradientLocations = [NSArray arrayWithObjects:
                                       [NSNumber numberWithFloat:0.0f],
                                       [NSNumber numberWithFloat:1.0f],
                                       [NSNumber numberWithFloat:0.51f],
                                       [NSNumber numberWithFloat:0.654f],
                                       nil];
    self.cornerRadius = 7.0f;
    [self setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
}
- (void) useRedDeleteStyle
{
    NSMutableArray *colors = [NSMutableArray arrayWithCapacity:5];
    UIColor *color = [UIColor colorWithRed:0.667f green:0.15f blue:0.152f alpha:1.0f];

    [colors addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.841f green:0.566f blue:0.566f alpha:1.0f];
    [colors addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.75f green:0.341f blue:0.345f alpha:1.0f];
    [colors addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.592f green:0.0f blue:0.0f alpha:1.0f];
    [colors addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.592f green:0.0f blue:0.0f alpha:1.0f];
    [colors addObject:(id)[color CGColor]];
    self.normalGradientColors = colors;
    self.normalGradientLocations = [NSArray arrayWithObjects:
                                    [NSNumber numberWithFloat:0.0f],
                                    [NSNumber numberWithFloat:1.0f],
                                    [NSNumber numberWithFloat:0.582f],
                                    [NSNumber numberWithFloat:0.418f],
                                    [NSNumber numberWithFloat:0.346f],
                                    nil];

    NSMutableArray *colors2 = [NSMutableArray arrayWithCapacity:5];
    color = [UIColor colorWithRed:0.467f green:0.009f blue:0.005f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.754f green:0.562f blue:0.562f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.543f green:0.212f blue:0.212f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.5f green:0.153f blue:0.152f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.388f green:0.004f blue:0.0f alpha:1.0f];
    [colors addObject:(id)[color CGColor]];

    self.highlightGradientColors = colors;
    self.highlightGradientLocations = [NSArray arrayWithObjects:
                                       [NSNumber numberWithFloat:0.0f],
                                       [NSNumber numberWithFloat:1.0f],
                                       [NSNumber numberWithFloat:0.715f],
                                       [NSNumber numberWithFloat:0.513f],
                                       [NSNumber numberWithFloat:0.445f],
                                       nil];
    self.cornerRadius = 9.f;
    [self setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
}
- (void) useWhiteStyle
{
    NSMutableArray *colors = [NSMutableArray arrayWithCapacity:3];
    UIColor *color = [UIColor colorWithRed:0.864f green:0.864f blue:0.864f alpha:1.0f];

    [colors addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.995f green:0.995f blue:0.995f alpha:1.0f];
    [colors addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.956f green:0.956f blue:0.955f alpha:1.0f];
    [colors addObject:(id)[color CGColor]];
    self.normalGradientColors = colors;
    self.normalGradientLocations = [NSMutableArray arrayWithObjects:
                                    [NSNumber numberWithFloat:0.0f],
                                    [NSNumber numberWithFloat:1.0f],
                                    [NSNumber numberWithFloat:0.601f],
                                    nil];

    NSMutableArray *colors2 = [NSMutableArray arrayWithCapacity:3];
    color = [UIColor colorWithRed:0.692f green:0.692f blue:0.691f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.995f green:0.995f blue:0.995f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.83f green:0.83f blue:0.83f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    self.highlightGradientColors = colors2;
    self.highlightGradientLocations = [NSMutableArray arrayWithObjects:
                                       [NSNumber numberWithFloat:0.0f],
                                       [NSNumber numberWithFloat:1.0f],
                                       [NSNumber numberWithFloat:0.601f],
                                       nil];

    self.cornerRadius = 9.f;
    [self setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [self setTitleColor:[UIColor darkGrayColor] forState:UIControlStateHighlighted];
}
- (void) useBlackStyle
{
    NSMutableArray *colors = [NSMutableArray arrayWithCapacity:4];
    UIColor *color = [UIColor colorWithRed:0.154f green:0.154f blue:0.154f alpha:1.0f];

    [colors addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.307f green:0.307f blue:0.307f alpha:1.0f];
    [colors addObject:(id)[color CGColor]];;
    color = [UIColor colorWithRed:0.166f green:0.166f blue:0.166f alpha:1.0f];
    [colors addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.118f green:0.118f blue:0.118f alpha:1.0f];
    [colors addObject:(id)[color CGColor]];
    self.normalGradientColors = colors;
    self.normalGradientLocations = [NSMutableArray arrayWithObjects:
                                    [NSNumber numberWithFloat:0.0f],
                                    [NSNumber numberWithFloat:1.0f],
                                    [NSNumber numberWithFloat:0.548f],
                                    [NSNumber numberWithFloat:0.462f],
                                    nil];
    self.cornerRadius = 9.0f;

    NSMutableArray *colors2 = [NSMutableArray arrayWithCapacity:4];
    color = [UIColor colorWithRed:0.199f green:0.199f blue:0.199f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.04f green:0.04f blue:0.04f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.074f green:0.074f blue:0.074f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.112f green:0.112f blue:0.112f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];

    self.highlightGradientColors = colors2;
    self.highlightGradientLocations = [NSMutableArray arrayWithObjects:
                                       [NSNumber numberWithFloat:0.0f],
                                       [NSNumber numberWithFloat:1.0f],
                                       [NSNumber numberWithFloat:0.548f],
                                       [NSNumber numberWithFloat:0.462f],
                                       nil];
    [self setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
}

- (void) useMyBlackStyle
{
    NSMutableArray *colors = [NSMutableArray arrayWithCapacity:4];
    UIColor *color = [UIColor colorWithRed:0.07f green:0.07f blue:0.07f alpha:1.0f];

    [colors addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.15f green:0.15f blue:0.15f alpha:1.0f];
    [colors addObject:(id)[color CGColor]];;
    color = [UIColor colorWithRed:0.08f green:0.08f blue:0.08f alpha:1.0f];
    [colors addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.06f green:0.06f blue:0.06f alpha:1.0f];
    [colors addObject:(id)[color CGColor]];
    self.normalGradientColors = colors;
    self.normalGradientLocations = [NSMutableArray arrayWithObjects:
                                    [NSNumber numberWithFloat:0.0f],
                                    [NSNumber numberWithFloat:1.0f],
                                    [NSNumber numberWithFloat:0.548f],
                                    [NSNumber numberWithFloat:0.462f],
                                    nil];
    self.cornerRadius = 9.0f;

    NSMutableArray *colors2 = [NSMutableArray arrayWithCapacity:4];
    color = [UIColor colorWithRed:0.10f green:0.10f blue:0.10f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.02f green:0.02f blue:0.02f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.04f green:0.04f blue:0.04f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.05f green:0.05f blue:0.05f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];

    self.highlightGradientColors = colors2;
    self.highlightGradientLocations = [NSMutableArray arrayWithObjects:
                                       [NSNumber numberWithFloat:0.0f],
                                       [NSNumber numberWithFloat:1.0f],
                                       [NSNumber numberWithFloat:0.548f],
                                       [NSNumber numberWithFloat:0.462f],
                                       nil];
    [self setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
    [self setNormalStrokeColor:[UIColor colorWithWhite:0.1f alpha:0.5f]];
    [self setNormalStrokeWeight:2.0f];
}

- (void) useMyInvertedBlackStyle
{
    NSMutableArray *colors = [NSMutableArray arrayWithCapacity:4];
    UIColor *color = [UIColor colorWithRed:0.07f green:0.07f blue:0.07f alpha:1.0f];

    [colors addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.15f green:0.15f blue:0.15f alpha:1.0f];
    [colors addObject:(id)[color CGColor]];;
    color = [UIColor colorWithRed:0.08f green:0.08f blue:0.08f alpha:1.0f];
    [colors addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.06f green:0.06f blue:0.06f alpha:1.0f];
    [colors addObject:(id)[color CGColor]];
    self.highlightGradientColors = colors;
    self.highlightGradientLocations = [NSMutableArray arrayWithObjects:
                                       [NSNumber numberWithFloat:0.0f],
                                       [NSNumber numberWithFloat:1.0f],
                                       [NSNumber numberWithFloat:0.548f],
                                       [NSNumber numberWithFloat:0.462f],
                                       nil];
    self.cornerRadius = 9.0f;

    NSMutableArray *colors2 = [NSMutableArray arrayWithCapacity:4];
    color = [UIColor colorWithRed:0.10f green:0.10f blue:0.10f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.02f green:0.02f blue:0.02f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.04f green:0.04f blue:0.04f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.05f green:0.05f blue:0.05f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];

    self.normalGradientColors = colors2;
    self.normalGradientLocations = [NSMutableArray arrayWithObjects:
                                    [NSNumber numberWithFloat:0.0f],
                                    [NSNumber numberWithFloat:1.0f],
                                    [NSNumber numberWithFloat:0.548f],
                                    [NSNumber numberWithFloat:0.462f],
                                    nil];
    [self setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
    [self setNormalStrokeColor:[UIColor colorWithWhite:0.1f alpha:0.5f]];
    [self setNormalStrokeWeight:2.0f];
}

- (void) useWhiteActionSheetStyle
{
    NSMutableArray *colors = [NSMutableArray arrayWithCapacity:3];
    UIColor *color = [UIColor colorWithRed:0.864f green:0.864f blue:0.864f alpha:1.0f];

    [colors addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.995f green:0.995f blue:0.995f alpha:1.0f];
    [colors addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.956f green:0.956f blue:0.955f alpha:1.0f];
    [colors addObject:(id)[color CGColor]];
    self.normalGradientColors = colors;
    self.normalGradientLocations = [NSMutableArray arrayWithObjects:
                                    [NSNumber numberWithFloat:0.0f],
                                    [NSNumber numberWithFloat:1.0f],
                                    [NSNumber numberWithFloat:0.601f],
                                    nil];

    NSMutableArray *colors2 = [NSMutableArray arrayWithCapacity:7];
    color = [UIColor colorWithRed:0.033f green:0.251f blue:0.673f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.66f green:0.701f blue:0.88f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.222f green:0.308f blue:0.709f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.145f green:0.231f blue:0.683f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.0f green:0.124f blue:0.621f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.011f green:0.181f blue:0.647f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.311f green:0.383f blue:0.748f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    self.highlightGradientColors = colors2;
    self.highlightGradientLocations = [NSMutableArray arrayWithObjects:
                                       [NSNumber numberWithFloat:0.0f],
                                       [NSNumber numberWithFloat:1.0f],
                                       [NSNumber numberWithFloat:0.957f],
                                       [NSNumber numberWithFloat:0.574f],
                                       [NSNumber numberWithFloat:0.541f],
                                       [NSNumber numberWithFloat:0.185f],
                                       [NSNumber numberWithFloat:0.812f],
                                       nil];

    self.cornerRadius = 9.f;
    [self setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [self setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
}
- (void) useBlackActionSheetStyle
{
    NSMutableArray *colors = [NSMutableArray arrayWithCapacity:4];
    UIColor *color = [UIColor colorWithRed:0.154f green:0.154f blue:0.154f alpha:1.0f];

    [colors addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.307f green:0.307f blue:0.307f alpha:1.0f];
    [colors addObject:(id)[color CGColor]];;
    color = [UIColor colorWithRed:0.166f green:0.166f blue:0.166f alpha:1.0f];
    [colors addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.118f green:0.118f blue:0.118f alpha:1.0f];
    [colors addObject:(id)[color CGColor]];
    self.normalGradientColors = colors;
    self.normalGradientLocations = [NSMutableArray arrayWithObjects:
                                    [NSNumber numberWithFloat:0.0f],
                                    [NSNumber numberWithFloat:1.0f],
                                    [NSNumber numberWithFloat:0.548f],
                                    [NSNumber numberWithFloat:0.462f],
                                    nil];
    self.cornerRadius = 9.0f;

    NSMutableArray *colors2 = [NSMutableArray arrayWithCapacity:7];
    color = [UIColor colorWithRed:0.033f green:0.251f blue:0.673f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.66f green:0.701f blue:0.88f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.222f green:0.308f blue:0.709f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.145f green:0.231f blue:0.683f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.0f green:0.124f blue:0.621f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.011f green:0.181f blue:0.647f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.311f green:0.383f blue:0.748f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    self.highlightGradientColors = colors2;
    self.highlightGradientLocations = [NSMutableArray arrayWithObjects:
                                       [NSNumber numberWithFloat:0.0f],
                                       [NSNumber numberWithFloat:1.0f],
                                       [NSNumber numberWithFloat:0.957f],
                                       [NSNumber numberWithFloat:0.574f],
                                       [NSNumber numberWithFloat:0.541f],
                                       [NSNumber numberWithFloat:0.185f],
                                       [NSNumber numberWithFloat:0.812f],
                                       nil];
    [self setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
}
- (void) useSimpleOrangeStyle
{
    NSMutableArray *colors = [NSMutableArray arrayWithCapacity:2];
    UIColor *color = [UIColor colorWithRed:0.935f green:0.403f blue:0.02f alpha:1.0f];

    [colors addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.97f green:0.582f blue:0.0f alpha:1.0f];
    [colors addObject:(id)[color CGColor]];
    self.normalGradientColors = colors;
    self.normalGradientLocations = [NSMutableArray arrayWithObjects:
                                    [NSNumber numberWithFloat:0.0f],
                                    [NSNumber numberWithFloat:1.0f],
                                    nil];

    NSMutableArray *colors2 = [NSMutableArray arrayWithCapacity:3];
    color = [UIColor colorWithRed:0.914f green:0.309f blue:0.0f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.935f green:0.4f blue:0.0f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.946f green:0.441f blue:0.01f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    self.highlightGradientColors = colors2;
    self.highlightGradientLocations = [NSMutableArray arrayWithObjects:
                                       [NSNumber numberWithFloat:0.0f],
                                       [NSNumber numberWithFloat:1.0f],
                                       [NSNumber numberWithFloat:0.498f],
                                       nil];

    self.cornerRadius = 9.f;
    [self setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
}
- (void) useGreenConfirmStyle
{
    NSMutableArray *colors = [NSMutableArray arrayWithCapacity:5];
    UIColor *color = [UIColor colorWithRed:0.15f green:0.667f blue:0.152f alpha:1.0f];

    [colors addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.566f green:0.841f blue:0.566f alpha:1.0f];
    [colors addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.341f green:0.75f blue:0.345f alpha:1.0f];
    [colors addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.0f green:0.592f blue:0.0f alpha:1.0f];
    [colors addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.0f green:0.592f blue:0.0f alpha:1.0f];
    [colors addObject:(id)[color CGColor]];
    self.normalGradientColors = colors;
    self.normalGradientLocations = [NSMutableArray arrayWithObjects:
                                    [NSNumber numberWithFloat:0.0f],
                                    [NSNumber numberWithFloat:1.0f],
                                    [NSNumber numberWithFloat:0.582f],
                                    [NSNumber numberWithFloat:0.418f],
                                    [NSNumber numberWithFloat:0.346f],
                                    nil];

    NSMutableArray *colors2 = [NSMutableArray arrayWithCapacity:5];
    color = [UIColor colorWithRed:0.009f green:0.467f blue:0.005f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.562f green:0.754f blue:0.562f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.212f green:0.543f blue:0.212f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.153f green:0.5f blue:0.152f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.004f green:0.388f blue:0.0f alpha:1.0f];
    [colors addObject:(id)[color CGColor]];

    self.highlightGradientColors = colors;
    self.highlightGradientLocations = [NSMutableArray arrayWithObjects:
                                       [NSNumber numberWithFloat:0.0f],
                                       [NSNumber numberWithFloat:1.0f],
                                       [NSNumber numberWithFloat:0.715f],
                                       [NSNumber numberWithFloat:0.513f],
                                       [NSNumber numberWithFloat:0.445f],
                                       nil];
    self.cornerRadius = 9.f;
    [self setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
}

- (void) useBlueStyle
{
    NSMutableArray *colors = [NSMutableArray arrayWithCapacity:5];
    UIColor *color = [UIColor colorWithRed:0.0f green:0.2f blue:1.0f alpha:1.0f];

    [colors addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.0f green:0.7f blue:1.0f alpha:1.0f];
    [colors addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.0f green:0.5f blue:1.0f alpha:1.0f];
    [colors addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.0f green:0.4f blue:1.0f alpha:1.0f];
    [colors addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.0f green:0.3f blue:1.0f alpha:1.0f];
    [colors addObject:(id)[color CGColor]];
    self.normalGradientColors = colors;
    self.normalGradientLocations = [NSMutableArray arrayWithObjects:
                                    [NSNumber numberWithFloat:0.0f],
                                    [NSNumber numberWithFloat:1.0f],
                                    [NSNumber numberWithFloat:0.582f],
                                    [NSNumber numberWithFloat:0.418f],
                                    [NSNumber numberWithFloat:0.346f],
                                    nil];

    NSMutableArray *colors2 = [NSMutableArray arrayWithCapacity:5];
    color = [UIColor colorWithRed:0.01f green:0.4f blue:0.7f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.6f green:0.75f blue:0.9f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.3f green:0.65f blue:0.9f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.15f green:0.5f blue:0.7f alpha:1.0f];
    [colors2 addObject:(id)[color CGColor]];
    color = [UIColor colorWithRed:0.01f green:0.3f blue:0.5f alpha:1.0f];
    [colors addObject:(id)[color CGColor]];

    self.highlightGradientColors = colors;
    self.highlightGradientLocations = [NSMutableArray arrayWithObjects:
                                       [NSNumber numberWithFloat:0.0f],
                                       [NSNumber numberWithFloat:1.0f],
                                       [NSNumber numberWithFloat:0.715f],
                                       [NSNumber numberWithFloat:0.513f],
                                       [NSNumber numberWithFloat:0.445f],
                                       nil];
    self.cornerRadius = 9.f;
    [self setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
}

#pragma mark -
- (void) drawRect:(CGRect)rect
{
    self.backgroundColor = [UIColor clearColor];
    CGRect imageBounds = CGRectMake(0.0, 0.0, (CGFloat)(self.bounds.size.width - 0.5), self.bounds.size.height);


    CGGradientRef gradient;
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGPoint point2;

    CGFloat resolution = (CGFloat)(0.5 * (self.bounds.size.width / imageBounds.size.width + self.bounds.size.height / imageBounds.size.height));

    CGFloat stroke = normalStrokeWeight * resolution;
    if (self.state == UIControlStateHighlighted)
    {
        stroke = highlightStrokeWeight * resolution;
    }
    if (self.state == UIControlStateDisabled)
    {
        stroke = disabledStrokeWeight * resolution;
    }
    if (stroke < 1.0)
        stroke = (CGFloat)ceil(stroke);
    else
        stroke = (CGFloat)round(stroke);
    stroke /= resolution;
    CGFloat alignStroke = (CGFloat)fmod(0.5 * stroke * resolution, 1.0);
    CGMutablePathRef path = CGPathCreateMutable();
    CGPoint point = CGPointMake((self.bounds.size.width - [self cornerRadius]), self.bounds.size.height - 0.5f);
    point.x = (CGFloat)(round(resolution * point.x + alignStroke) - alignStroke) / resolution;
    point.y = (CGFloat)(round(resolution * point.y + alignStroke) - alignStroke) / resolution;
    CGPathMoveToPoint(path, NULL, point.x, point.y);
    point = CGPointMake(self.bounds.size.width - 0.5f, (self.bounds.size.height - [self cornerRadius]));
    point.x = (CGFloat)(round(resolution * point.x + alignStroke) - alignStroke) / resolution;
    point.y = (CGFloat)(round(resolution * point.y + alignStroke) - alignStroke) / resolution;
    CGPoint controlPoint1 = CGPointMake((self.bounds.size.width - ([self cornerRadius] / 2.f)), self.bounds.size.height - 0.5f);
    controlPoint1.x = (CGFloat)(round(resolution * controlPoint1.x + alignStroke) - alignStroke) / resolution;
    controlPoint1.y = (CGFloat)(round(resolution * controlPoint1.y + alignStroke) - alignStroke) / resolution;
    CGPoint controlPoint2 = CGPointMake(self.bounds.size.width - 0.5f, (self.bounds.size.height - ([self cornerRadius] / 2.f)));
    controlPoint2.x = (CGFloat)(round(resolution * controlPoint2.x + alignStroke) - alignStroke) / resolution;
    controlPoint2.y = (CGFloat)(round(resolution * controlPoint2.y + alignStroke) - alignStroke) / resolution;
    CGPathAddCurveToPoint(path, NULL, controlPoint1.x, controlPoint1.y, controlPoint2.x, controlPoint2.y, point.x, point.y);
    point = CGPointMake(self.bounds.size.width - 0.5f, [self cornerRadius]);
    point.x = (CGFloat)(round(resolution * point.x + alignStroke) - alignStroke) / resolution;
    point.y = (CGFloat)(round(resolution * point.y + alignStroke) - alignStroke) / resolution;
    CGPathAddLineToPoint(path, NULL, point.x, point.y);
    point = CGPointMake((self.bounds.size.width - [self cornerRadius]), 0.0);
    point.x = (CGFloat)(round(resolution * point.x + alignStroke) - alignStroke) / resolution;
    point.y = (CGFloat)(round(resolution * point.y + alignStroke) - alignStroke) / resolution;
    controlPoint1 = CGPointMake(self.bounds.size.width - 0.5f, ([self cornerRadius] / 2.f));
    controlPoint1.x = (CGFloat)(round(resolution * controlPoint1.x + alignStroke) - alignStroke) / resolution;
    controlPoint1.y = (CGFloat)(round(resolution * controlPoint1.y + alignStroke) - alignStroke) / resolution;
    controlPoint2 = CGPointMake((self.bounds.size.width - ([self cornerRadius] / 2.f)), 0.0);
    controlPoint2.x = (CGFloat)(round(resolution * controlPoint2.x + alignStroke) - alignStroke) / resolution;
    controlPoint2.y = (CGFloat)(round(resolution * controlPoint2.y + alignStroke) - alignStroke) / resolution;
    CGPathAddCurveToPoint(path, NULL, controlPoint1.x, controlPoint1.y, controlPoint2.x, controlPoint2.y, point.x, point.y);
    point = CGPointMake([self cornerRadius], 0.0);
    point.x = (CGFloat)(round(resolution * point.x + alignStroke) - alignStroke) / resolution;
    point.y = (CGFloat)(round(resolution * point.y + alignStroke) - alignStroke) / resolution;
    CGPathAddLineToPoint(path, NULL, point.x, point.y);
    point = CGPointMake(0.0, [self cornerRadius]);
    point.x = (CGFloat)(round(resolution * point.x + alignStroke) - alignStroke) / resolution;
    point.y = (CGFloat)(round(resolution * point.y + alignStroke) - alignStroke) / resolution;
    controlPoint1 = CGPointMake(([self cornerRadius] / 2.f), 0.0);
    controlPoint1.x = (CGFloat)(round(resolution * controlPoint1.x + alignStroke) - alignStroke) / resolution;
    controlPoint1.y = (CGFloat)(round(resolution * controlPoint1.y + alignStroke) - alignStroke) / resolution;
    controlPoint2 = CGPointMake(0.0, ([self cornerRadius] / 2.f));
    controlPoint2.x = (CGFloat)(round(resolution * controlPoint2.x + alignStroke) - alignStroke) / resolution;
    controlPoint2.y = (CGFloat)(round(resolution * controlPoint2.y + alignStroke) - alignStroke) / resolution;
    CGPathAddCurveToPoint(path, NULL, controlPoint1.x, controlPoint1.y, controlPoint2.x, controlPoint2.y, point.x, point.y);
    point = CGPointMake(0.0, (self.bounds.size.height - [self cornerRadius]));
    point.x = (CGFloat)(round(resolution * point.x + alignStroke) - alignStroke) / resolution;
    point.y = (CGFloat)(round(resolution * point.y + alignStroke) - alignStroke) / resolution;
    CGPathAddLineToPoint(path, NULL, point.x, point.y);
    point = CGPointMake([self cornerRadius], self.bounds.size.height - 0.5f);
    point.x = (CGFloat)(round(resolution * point.x + alignStroke) - alignStroke) / resolution;
    point.y = (CGFloat)(round(resolution * point.y + alignStroke) - alignStroke) / resolution;
    controlPoint1 = CGPointMake(0.0, (self.bounds.size.height - ([self cornerRadius] / 2.f)));
    controlPoint1.x = (CGFloat)(round(resolution * controlPoint1.x + alignStroke) - alignStroke) / resolution;
    controlPoint1.y = (CGFloat)(round(resolution * controlPoint1.y + alignStroke) - alignStroke) / resolution;
    controlPoint2 = CGPointMake(([self cornerRadius] / 2.f), self.bounds.size.height - 0.5f);
    controlPoint2.x = (CGFloat)(round(resolution * controlPoint2.x + alignStroke) - alignStroke) / resolution;
    controlPoint2.y = (CGFloat)(round(resolution * controlPoint2.y + alignStroke) - alignStroke) / resolution;
    CGPathAddCurveToPoint(path, NULL, controlPoint1.x, controlPoint1.y, controlPoint2.x, controlPoint2.y, point.x, point.y);
    point = CGPointMake((self.bounds.size.width - [self cornerRadius]), self.bounds.size.height - 0.5f);
    point.x = (CGFloat)(round(resolution * point.x + alignStroke) - alignStroke) / resolution;
    point.y = (CGFloat)(round(resolution * point.y + alignStroke) - alignStroke) / resolution;
    CGPathAddLineToPoint(path, NULL, point.x, point.y);
    CGPathCloseSubpath(path);
    if (self.state == UIControlStateHighlighted)
    {
        gradient = self.highlightGradient;
    }
    else if (self.state == UIControlStateDisabled)
    {
        gradient = self.disabledGradient;
    }
    else
    {
        gradient = self.normalGradient;
    }

    CGContextAddPath(context, path);
    CGContextSaveGState(context);
    CGContextEOClip(context);
    point = CGPointMake((CGFloat)(self.bounds.size.width / 2.0), self.bounds.size.height - 0.5f);
    point2 = CGPointMake((CGFloat)(self.bounds.size.width / 2.0), 0.0);
    CGContextDrawLinearGradient(context, gradient, point, point2, (kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation));
    CGContextRestoreGState(context);
    if (self.state == UIControlStateHighlighted)
    {
        [highlightStrokeColor setStroke];
    }
    else if (self.state == UIControlStateDisabled)
    {
        [disabledStrokeColor setStroke];
    }
    else
    {
        [normalStrokeColor setStroke];
    }
    CGContextSetLineWidth(context, stroke);
    CGContextSetLineCap(context, kCGLineCapSquare);
    CGContextAddPath(context, path);
    CGContextStrokePath(context);
    CGPathRelease(path);
}

#pragma mark -
#pragma mark Touch Handling
- (void) hesitateUpdate
{
    [self setNeedsDisplay];
}
- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    [self setNeedsDisplay];
}
- (void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesCancelled:touches withEvent:event];
    [self setNeedsDisplay];
    [self performSelector:@selector(hesitateUpdate) withObject:nil afterDelay:0.1];
}
- (void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesMoved:touches withEvent:event];
    [self setNeedsDisplay];
}
- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesEnded:touches withEvent:event];
    [self setNeedsDisplay];
    [self performSelector:@selector(hesitateUpdate) withObject:nil afterDelay:0.1];
}

#pragma mark -
#pragma mark NSCoding
- (void) encodeWithCoder:(NSCoder *)encoder
{
    [super encodeWithCoder:encoder];
    
    [encoder encodeObject:[self normalGradientColors] forKey:@"normalGradientColors"];
    [encoder encodeObject:[self normalGradientLocations] forKey:@"normalGradientLocations"];
    [encoder encodeObject:[self normalStrokeColor] forKey:@"normalStrokeColor"];;
    
    [encoder encodeObject:[self highlightGradientColors] forKey:@"highlightGradientColors"];
    [encoder encodeObject:[self highlightGradientLocations] forKey:@"highlightGradientLocations"];
    [encoder encodeObject:[self highlightStrokeColor] forKey:@"highlightStrokeColor"];
    
    [encoder encodeObject:[self disabledGradientColors] forKey:@"disabledGradientColors"];
    [encoder encodeObject:[self disabledGradientLocations] forKey:@"disabledGradientLocations"];
    [encoder encodeObject:[self disabledStrokeColor] forKey:@"disabledStrokeColor"];
}

- (id) initWithCoder:(NSCoder *)decoder
{
    self = [super initWithCoder:decoder];

    if (self)
    {   
        [self setNormalGradientColors:[decoder decodeObjectForKey:@"normalGradientColors"]];
        [self setNormalGradientLocations:[decoder decodeObjectForKey:@"normalGradientLocations"]];
        [self setNormalStrokeColor:[decoder decodeObjectForKey:@"normalStrokeColor"]];
        
        [self setHighlightGradientColors:[decoder decodeObjectForKey:@"highlightGradientColors"]];
        [self setHighlightGradientLocations:[decoder decodeObjectForKey:@"highlightGradientLocations"]];
        [self setHighlightStrokeColor:[decoder decodeObjectForKey:@"highlightStrokeColor"]];
        
        [self setDisabledGradientColors:[decoder decodeObjectForKey:@"disabledGradientColors"]];
        [self setDisabledGradientLocations:[decoder decodeObjectForKey:@"disabledGradientLocations"]];
        [self setDisabledStrokeColor:[decoder decodeObjectForKey:@"disabledStrokeColor"]];
        
        if (self.normalStrokeColor == nil)
        {
            self.normalStrokeColor = [UIColor colorWithRed:0.076f green:0.103f blue:0.195f alpha:1.0f];
        }
        
        if (self.highlightStrokeColor == nil)
        {
            self.highlightStrokeColor = self.normalStrokeColor;
        }
        
        if (self.disabledStrokeColor == nil)
        {
            CGFloat hue;
            CGFloat saturation;
            CGFloat brightness;
            
            [UIColor 
             red:[self.normalStrokeColor red] green:[self.normalStrokeColor green] blue:[self.normalStrokeColor blue] 
             toHue:&hue saturation:&saturation brightness:&brightness
            ];
            
            self.disabledStrokeColor = [UIColor colorWithHue:hue saturation:(saturation/3.0) brightness:brightness+((1.0-brightness)/2.0) alpha:1.0];
        }
        
        self.normalStrokeWeight = 1.0;
        self.highlightStrokeWeight = self.normalStrokeWeight;
        self.disabledStrokeWeight = self.normalStrokeWeight;
        
        if (self.normalGradientColors == nil)
        {
            [self useWhiteStyle];
        }

        [self setOpaque:NO];
        self.backgroundColor = [UIColor colorWithRed:1.0f green:1.0f blue:1.0 alpha:0.0];
    }
    return self;
}

#pragma mark -
- (void) dealloc
{
    [normalGradientColors release];
    [normalGradientLocations release];
    [normalStrokeColor release];
    
    [highlightGradientColors release];
    [highlightGradientLocations release];
    [highlightStrokeColor release];
    
    [disabledGradientColors release];
    [disabledGradientLocations release];
    [disabledStrokeColor release];

    if (normalGradient != NULL)
    {
        CGGradientRelease(normalGradient);
    }

    if (highlightGradient != NULL)
    {
        CGGradientRelease(highlightGradient);
    }


    [super dealloc];
}

@end
