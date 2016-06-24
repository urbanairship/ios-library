/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

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

#import "UAInAppMessageControllerDefaultDelegate.h"
#import "UAInAppMessage.h"
#import "UAInAppMessageView+Internal.h"
#import "UAirship.h"
#import "UAInAppMessaging.h"
#import "UAInAppMessageButtonActionBinding.h"
#import "UANotificationCategory.h"
#import "UAUtils.h"
#import "NSString+UALocalizationAdditions.h"


#define kUAInAppMessageAnimationDuration 0.2
#define kUAInAppMessageiPhoneScreenWidthPercentage 0.95
#define kUAInAppMessagePadScreenWidthPercentage 0.45

@interface UAInAppMessageControllerDefaultDelegate ()

@property(nonatomic, assign) UAInAppMessagePosition position;
@property(nonatomic, strong) UIColor *primaryColor;
@property(nonatomic, strong) UIColor *secondaryColor;
@property(nonatomic, strong) NSArray *layoutConstraints;
@property(nonatomic, copy) void (^updateLayoutConstraintsBlock)(void);
@property(nonatomic, assign) UIUserInterfaceSizeClass lastHorizontalSizeClass;
@property(nonatomic, assign) BOOL isInverted;

@end

@implementation UAInAppMessageControllerDefaultDelegate

- (instancetype)initWithMessage:(UAInAppMessage *)message {
    self = [super init];
    if (self) {
        // The primary and secondary colors aren't set in the model, choose sensible defaults
        self.position = message.position;
        self.primaryColor = message.primaryColor ?: [UAirship inAppMessaging].defaultPrimaryColor;
        self.secondaryColor = message.secondaryColor ?: [UAirship inAppMessaging].defaultSecondaryColor;
    }
    return self;
}

/**
 * Configures primary and secondary colors in the message view, inverting the color
 * scheme if necessary.
 */
- (void)configureColorsWithMessageView:(UAInAppMessageView *)messageView inverted:(BOOL)inverted {

    UIColor *primaryColor;
    UIColor *secondaryColor;

    if (inverted) {
        primaryColor = self.secondaryColor;
        secondaryColor = self.primaryColor;
    } else {
        primaryColor = self.primaryColor;
        secondaryColor = self.secondaryColor;
    }

    messageView.backgroundColor = primaryColor;

    messageView.tab.backgroundColor = secondaryColor;

    messageView.messageLabel.textColor = secondaryColor;

    [messageView.button1 setTitleColor:primaryColor forState:UIControlStateNormal];
    [messageView.button2 setTitleColor:primaryColor forState:UIControlStateNormal];
    messageView.button1.backgroundColor = secondaryColor;
    messageView.button2.backgroundColor = secondaryColor;
}

- (void)invertColorsWithMessageView:(UAInAppMessageView *)messageView {
    if (!self.isInverted) {
        [self configureColorsWithMessageView:messageView inverted:YES];
        self.isInverted = YES;
    }
}

- (void)uninvertColorsWithMessageView:(UAInAppMessageView *)messageView {
    if (self.isInverted) {
        [self configureColorsWithMessageView:messageView inverted:NO];
        self.isInverted = NO;
    }
}

- (NSString *)localizedButtonTitleForKey:(NSString *)key {
    return [key localizedStringWithTable:@"UrbanAirship"];
}

/**
 * Builds the UAInAppMessageView, configuring it with data from the message
 */
- (UAInAppMessageView *)buildMessageViewForMessage:(UAInAppMessage *)message {

    UIFont *messageFont = [UAirship inAppMessaging].font;

    // Button action bindings are an array of UAInAppMessageButtonActionBinding instances,
    // which represent a binding between an in-app message button, a localized title and action
    // name/argument pairs.
    NSArray *buttonActionBindings = message.buttonActionBindings;

    UAInAppMessageView *messageView = [[UAInAppMessageView alloc] initWithPosition:message.position
                                                                   numberOfButtons:buttonActionBindings.count];

    // Configure all the subviews
    messageView.messageLabel.text = message.alert;
    messageView.messageLabel.numberOfLines = 4;
    messageView.messageLabel.font = messageFont;

    messageView.button1.titleLabel.font = messageFont;
    messageView.button2.titleLabel.font = messageFont;

    // Set button titles accordingly
    if (buttonActionBindings.count) {
        UAInAppMessageButtonActionBinding *button1 = buttonActionBindings[0];

        [messageView.button1 setTitle:button1.title forState:UIControlStateNormal];
        if (buttonActionBindings.count > 1) {
            UAInAppMessageButtonActionBinding *button2 = buttonActionBindings[1];
            [messageView.button2 setTitle:button2.title forState:UIControlStateNormal];
        }
    }

    // Configure default colors
    [self configureColorsWithMessageView:messageView inverted:NO];

    // Update layout constraints if needed
    messageView.onLayoutSubviews = ^{
        [self updateLayoutConstraintsIfNeeded];
    };

    return messageView;
}

- (void)updateLayoutConstraintsWithParent:(UIView *)parentView metrics:(id)metrics views:(id)views {

    NSString *verticalLayout;

    // Place the message view flush against the top or bottom of the parent, depending on position
    if (self.position == UAInAppMessagePositionBottom) {
        verticalLayout = @"V:[messageView]|";
    } else {
        verticalLayout = @"V:|[messageView]";
    }

    NSString *regularWidthHorizontalLayout = @"[messageView(regularMessageWidth)]";
    NSString *compactWidthHorizontalLayout = @"H:|-horizontalMargin-[messageView]-horizontalMargin-|";

    NSString *horizontalLayout;

    UIWindow *window = [UAUtils mainWindow];
    if ([[UIDevice currentDevice].systemVersion floatValue] >= 8.0) {

        UITraitCollection *traitCollection = window.traitCollection;

        UIUserInterfaceSizeClass horizontalSizeClass = traitCollection.horizontalSizeClass;
        UIUserInterfaceSizeClass verticalSizeClass = traitCollection.verticalSizeClass;

        if (horizontalSizeClass == UIUserInterfaceSizeClassRegular && verticalSizeClass == UIUserInterfaceSizeClassRegular) {
            horizontalLayout = regularWidthHorizontalLayout;
        } else {
            horizontalLayout = compactWidthHorizontalLayout;
        }
    } else {
        // If the UI idiom is iPad, use the fixed width, otherwise offset it with the horizontal margins
        if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            horizontalLayout = regularWidthHorizontalLayout;
        } else {
            horizontalLayout = compactWidthHorizontalLayout;
        }
    }


    if (self.layoutConstraints) {
        [parentView removeConstraints:self.layoutConstraints];
    }

    NSMutableArray *allConstraints = [NSMutableArray array];

    for (NSString *expression in @[verticalLayout, horizontalLayout]) {
        NSArray *constraints = [NSLayoutConstraint constraintsWithVisualFormat:expression
                                                                       options:0
                                                                       metrics:metrics
                                                                         views:views];
        [allConstraints addObjectsFromArray:constraints];

    }

    self.layoutConstraints = allConstraints;

    [parentView addConstraints:allConstraints];
};

/**
 * Adds layout constraints to the message view.
 */
- (void)buildLayoutWithParent:(UIView *)parentView messageView:(UIView *)messageView {
    CGFloat horizontalMargin = 0;
    CGRect windowBounds = [UAUtils orientationDependentWindowBounds];
    CGFloat screenWidth = CGRectGetWidth(windowBounds);

    // For the horizontal and vertical regular size class, messages are 45% of the fixed screen width in landscape
    CGFloat longWidth = MAX(screenWidth, CGRectGetHeight(windowBounds));
    CGFloat regularMessageWidth = longWidth * kUAInAppMessagePadScreenWidthPercentage;

    // For the horizontal or vertical compact size class, messages are always 95% of current screen width
    CGFloat compactMessageWidth = screenWidth*kUAInAppMessageiPhoneScreenWidthPercentage;

    horizontalMargin = (screenWidth - compactMessageWidth)/2.0;

    id metrics = @{@"horizontalMargin":@(horizontalMargin), @"regularMessageWidth":@(regularMessageWidth)};
    id views = @{@"messageView":messageView};

    [parentView addSubview:messageView];

    // Center the message view in the parent (this cannot be expressed in VFL)
    [parentView addConstraint:[NSLayoutConstraint constraintWithItem:messageView
                                                           attribute:NSLayoutAttributeCenterX
                                                           relatedBy:NSLayoutRelationEqual
                                                              toItem:parentView
                                                           attribute:NSLayoutAttributeCenterX multiplier:1
                                                            constant:0]];

    // Executing this block will calculate/recalculate layout constraints
    __weak UAInAppMessageControllerDefaultDelegate *weakSelf = self;
    self.updateLayoutConstraintsBlock = ^{
        UAInAppMessageControllerDefaultDelegate *strongSelf = weakSelf;

        [strongSelf updateLayoutConstraintsWithParent:parentView metrics:metrics views:views];
    };

    self.updateLayoutConstraintsBlock();
}

- (void)updateLayoutConstraintsIfNeeded {
    // If we're running on iOS 8 or above
    if ([[UIDevice currentDevice].systemVersion floatValue] >= 8.0) {
        // Get the current horizontal size class
        UIUserInterfaceSizeClass horizontalSizeClass = [UAUtils mainWindow].traitCollection.horizontalSizeClass;
        // If there has been a change, update layout constraints
        if (horizontalSizeClass != self.lastHorizontalSizeClass) {
            self.lastHorizontalSizeClass = horizontalSizeClass;
            self.updateLayoutConstraintsBlock();
        }
    }
}

- (UIView *)viewForMessage:(UAInAppMessage *)message parentView:(UIView *)parentView {

    // Build the messageView, configuring it with data from the message
    UIView *messageView = [self buildMessageViewForMessage:message];

    // Build and add the autolayout constraints that situate the message view in its parent
    [self buildLayoutWithParent:parentView messageView:messageView];

    return messageView;
}

- (UIControl *)messageView:(UIView *)messageView buttonAtIndex:(NSUInteger)index {
    UAInAppMessageView *uaMessageView = (UAInAppMessageView *) messageView;

    // Index 0 corresponds to buton1, index 1 corresponds to button 2.
    if (index == 0) {
        return uaMessageView.button1;
    } else if (index == 1) {
        return uaMessageView.button2;
    }
    return nil;
}

- (void)messageView:(UIView *)messageView didChangeTouchState:(BOOL)touchDown {
    UAInAppMessageView *uaMessageView = (UAInAppMessageView *)messageView;

    // If YES invert the primary and secondary colors, otherwise uninvert.
    if (touchDown) {
        [self invertColorsWithMessageView:uaMessageView];
    } else {
        [self uninvertColorsWithMessageView:uaMessageView];
    }
}

- (void)messageView:(UIView *)messageView animateInWithParentView:(UIView *)parentView completionHandler:(void (^)(void))completionHandler {
    // Save and offset the message view's original center point for animation in
    CGPoint originalCenter = messageView.center;
    if (self.position == UAInAppMessagePositionTop) {
        messageView.center = CGPointMake(originalCenter.x, -(CGRectGetHeight(messageView.frame)/2));
    } else if (self.position == UAInAppMessagePositionBottom) {
        messageView.center = CGPointMake(originalCenter.x, CGRectGetHeight(parentView.frame) + CGRectGetHeight(messageView.frame)/2);
    }

    [UIView animateWithDuration:kUAInAppMessageAnimationDuration delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        messageView.center = originalCenter;
    } completion:^(BOOL finished) {
        completionHandler();
    }];
}

- (void)messageView:(UIView *)messageView animateOutWithParentView:(UIView *)parentView completionHandler:(void (^)(void))completionHandler {
    [UIView animateWithDuration:kUAInAppMessageAnimationDuration delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        if (self.position == UAInAppMessagePositionTop) {
            messageView.center = CGPointMake(messageView.center.x, -(CGRectGetHeight(messageView.frame)));
        } else {
            messageView.center = CGPointMake(messageView.center.x, messageView.center.y + (CGRectGetHeight(messageView.frame)));
        }
    } completion:^(BOOL finished){
        completionHandler();
    }];
}

@end
