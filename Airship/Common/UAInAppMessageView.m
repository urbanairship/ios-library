/*
 Copyright 2009-2015 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

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

#import "UAInAppMessageView.h"

// shadow offset on the y axis of 1 point
#define kUAInAppMessageViewShadowOffsetY 1

// shadow radius of 3 points
#define kUAInAppMessageViewShadowRadius 3

// 25% shadow opacity
#define kUAInAppMessageViewShadowOpacity 0.25

// a corner radius of 4 points
#define kUAInAppMessageViewCornerRadius 4

@interface UAInAppMessageView ()

@property(nonatomic, strong) UIView *containerView;
@property(nonatomic, strong) UIView *maskView;
@property(nonatomic, strong) UIView *tab;
@property(nonatomic, strong) UILabel *messageLabel;
@property(nonatomic, strong) UIButton *button1;
@property(nonatomic, strong) UIButton *button2;

@end

@implementation UAInAppMessageView

- (instancetype)initWithPosition:(UAInAppMessagePosition)position numberOfButtons:(NSUInteger)numberOfButtons {
    self = [super init];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;

        // be transparent at the top, in order to facilitate masking of subviews
        self.backgroundColor = [UIColor clearColor];

        // contains all the meaningful subviews
        self.containerView = [UIView new];
        self.containerView.translatesAutoresizingMaskIntoConstraints = NO;
        self.containerView.backgroundColor = [UIColor whiteColor];

        // covers up rounded corners in the appropriate area
        self.maskView = [UIView new];
        self.maskView.translatesAutoresizingMaskIntoConstraints = NO;
        self.maskView.userInteractionEnabled = NO;
        self.maskView.backgroundColor = [UIColor whiteColor];

        CGFloat shadowOffsetY;

        // if on the bottom, project the shadow on the top edge
        if (position == UAInAppMessagePositionBottom) {
            shadowOffsetY = -kUAInAppMessageViewShadowOffsetY;
        } else {
            // otherwise project it on the bottom edge
            shadowOffsetY = kUAInAppMessageViewShadowOffsetY;
        }

        self.containerView.layer.shadowOffset = CGSizeMake(0, shadowOffsetY);
        self.containerView.layer.shadowRadius = kUAInAppMessageViewShadowRadius;
        self.containerView.layer.shadowOpacity = kUAInAppMessageViewShadowOpacity;
        self.containerView.layer.cornerRadius = 4;

        self.messageLabel = [UILabel new];
        self.messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.messageLabel.userInteractionEnabled = NO;

        [self.containerView addSubview:self.messageLabel];

        self.tab = [UIView new];
        self.tab.translatesAutoresizingMaskIntoConstraints = NO;
        self.tab.layer.cornerRadius = 4;
        self.tab.autoresizesSubviews = YES;
        [self.containerView addSubview:self.tab];

        // add buttons depending on the passed number
        if (numberOfButtons) {
            self.button1 = [self buildButton];
            [self.containerView addSubview:self.button1];

            if (numberOfButtons > 1) {
                self.button2 = [self buildButton];
                [self.containerView addSubview:self.button2];
            }
        }

        [self addSubview:self.containerView];
        [self addSubview:self.maskView];

        [self buildLayoutWithPosition:position numberOfButtons:numberOfButtons];
    }

    return self;
}


// when setting the background color, pass through to the
// containerView and maskView, leaving self clear.
- (void)setBackgroundColor:(UIColor *)backgroundColor {
    self.containerView.backgroundColor = backgroundColor;
    self.maskView.backgroundColor = backgroundColor;
}

- (UIButton *)buildButton {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    // rounded corners
    button.layer.cornerRadius = 4;
    return button;
}

- (NSArray *)constraintsForBottomPositionWithNumberOfButtons:(NSUInteger)numberOfButtons {
    NSMutableArray *constraints = [NSMutableArray array];

    // tab is at the top, followed by the label
    [constraints addObject:@"V:|-tabMargin-[tab]-verticalMargin-[label]"];

    // 0 buttons
    if (!numberOfButtons) {
        // label is followed by the edge
        [constraints addObject:@"V:[label]-verticalMargin-|"];
    } else if (numberOfButtons == 1) {
        // button 1 is vertically positioned underneath the label
        [constraints addObject:@"V:[label]-verticalMargin-[button1]-verticalMargin-|"];

        // button 1 takes up all space apart from margins on either side
        [constraints addObject:@"H:|-horizontalMargin-[button1]-horizontalMargin-|"];
    } else if (numberOfButtons > 1) {
        // button 1 is vertically positioned underneath the label
        [constraints addObject:@"V:[label]-verticalMargin-[button1]-verticalMargin-|"];

        // button 2 is vertically positioned underneath the label, followed by the edge
        [constraints addObject:@"V:[label]-verticalMargin-[button2]-verticalMargin-|"];

        // button 1 and two are equal in size
        [constraints addObject:@"H:|-horizontalMargin-[button1]-horizontalMargin-[button2(==button1)]-horizontalMargin-|"];
    }

    // cover up the rounded corners at the bottom
    [constraints addObject:@"V:[mask(maskHeight)]|"];

    return constraints;
}

- (NSArray *)constraintsForTopPositionWithNumberOfButtons:(NSUInteger)numberOfButtons {
    NSMutableArray *constraints = [NSMutableArray array];

    // label is at the top
    [constraints addObject:@"V:|-verticalMargin-[label]"];

    // 0 buttons
    if (!numberOfButtons) {
        // label is followed by the tab and the edge
        [constraints addObject:@"V:[label]-verticalMargin-[tab]-tabMargin-|"];
    } else if (numberOfButtons == 1) {
        // button 1 is positioned beneath the label, followed by the tab and the edge
        [constraints addObject:@"V:[label]-verticalMargin-[button1]-verticalMargin-[tab]-tabMargin-|"];

        // button 1 takes up all space apart from margins on either side
        [constraints addObject:@"H:|-horizontalMargin-[button1]-horizontalMargin-|"];

    } else if (numberOfButtons > 1) {
        // button 2 is position beneath the label, followed by the tab and the edge
        [constraints addObject:@"V:[label]-verticalMargin-[button2]-verticalMargin-[tab]-tabMargin-|"];

        // button 1 is positioned beneath the label, followed by the tab and the edge
        [constraints addObject:@"V:[label]-verticalMargin-[button1]-verticalMargin-[tab]-tabMargin-|"];

        // button 1 and two are equal in size
        [constraints addObject:@"H:|-horizontalMargin-[button1]-horizontalMargin-[button2(==button1)]-horizontalMargin-|"];
    }

    // cover up the rounded corners at the top
    [constraints addObject:@"V:|[mask(maskHeight)]"];

    return constraints;
}

- (void)buildLayoutWithPosition:(UAInAppMessagePosition)position numberOfButtons:(NSUInteger)numberOfButtons {

    // layout constants
    CGFloat verticalMargin = 10;
    CGFloat horizontalMargin = 10;
    CGFloat tabHeight = 3;
    CGFloat tabWidth = 35;
    CGFloat tabMargin = 5;

    // views and metrics dictionaries for binding in VFL expressions
    NSMutableDictionary *views = [NSMutableDictionary dictionary];
    [views setValue:self.tab forKey:@"tab"];
    [views setValue:self.messageLabel forKey:@"label"];
    [views setValue:self.button1 forKey:@"button1"];
    [views setValue:self.button2 forKey:@"button2"];
    [views setValue:self.containerView forKey:@"container"];
    [views setValue:self.maskView forKey:@"mask"];

    id metrics = @{@"verticalMargin": @(verticalMargin),
                   @"horizontalMargin":@(horizontalMargin),
                   @"tabMargin":@(tabMargin),
                   @"tabHeight":@(tabHeight),
                   @"tabWidth":@(tabWidth),
                   @"maskHeight":@(kUAInAppMessageViewCornerRadius)};


    // centering the tab requires laying out a constraint the hard way
    [self addConstraint:[NSLayoutConstraint constraintWithItem:views[@"tab"]
                                                     attribute:NSLayoutAttributeCenterX
                                                     relatedBy:NSLayoutRelationEqual
                                                        toItem:self
                                                     attribute:NSLayoutAttributeCenterX
                                                    multiplier:1 constant:0]];

    // constraints common to all configurations
    NSArray *commonConstraints = @[@"H:|[container]|",
                                   @"V:|[container]|",
                                   @"H:|[mask]|",
                                   @"H:[tab(tabWidth)]", // set the tab width
                                   @"V:[tab(tabHeight)]", // set the tab height
                                   @"H:|-horizontalMargin-[label]-horizontalMargin-|"]; // label is inset by the horizontal margin


    // constraints that vary depending on position and number of buttons present
    NSMutableArray *positionalConstraints = [NSMutableArray array];


    if (position == UAInAppMessagePositionBottom) {
        [positionalConstraints addObjectsFromArray:[self constraintsForBottomPositionWithNumberOfButtons:numberOfButtons]];
    } else {
        [positionalConstraints addObjectsFromArray:[self constraintsForTopPositionWithNumberOfButtons:numberOfButtons]];
    }

    // add all the constraints
    for (NSString *formatString in [commonConstraints arrayByAddingObjectsFromArray:positionalConstraints]) {
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:formatString
                                                                     options:0
                                                                     metrics:metrics
                                                                       views:views]];
    }
}

@end

