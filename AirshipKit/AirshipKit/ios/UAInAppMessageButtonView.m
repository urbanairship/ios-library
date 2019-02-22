/* Copyright Urban Airship and Contributors */

#import "UAirship.h"
#import "UAInAppMessageButtonView+Internal.h"
#import "UAColorUtils+Internal.h"
#import "UAInAppMessageUtils+Internal.h"
#import "UAInAppMessageBannerDisplayContent.h"
#import "UAInAppMessageButton+Internal.h"
#import "UAColorUtils+Internal.h"

// UAInAppMessageButtonView nib name
NSString *const UAInAppMessageButtonViewNibName = @"UAInAppMessageButtonView";

CGFloat const DefaultStackedButtonSpacing = 24;
CGFloat const DefaultSeparatedButtonSpacing = 16;

@implementation UAInAppMessageButtonView

+ (instancetype)buttonViewWithButtons:(NSArray<UAInAppMessageButtonInfo *> *)buttons
                               layout:(UAInAppMessageButtonLayoutType)layout
                                style:(UAInAppMessageButtonStyle *)style
                               target:(id)target
                             selector:(SEL)selector {

    NSString *nibName = UAInAppMessageButtonViewNibName;
    NSBundle *bundle = [UAirship resources];

    // Joined, Separate and Stacked views object at index 0,1,2, respectively.
    UAInAppMessageButtonView *view;
    switch (layout) {
        case UAInAppMessageButtonLayoutTypeJoined:
            view = [[bundle loadNibNamed:nibName owner:nil options:nil] objectAtIndex:0];
            break;
        case UAInAppMessageButtonLayoutTypeSeparate:
            view = [[bundle loadNibNamed:nibName owner:nil options:nil] objectAtIndex:1];
            break;
        case UAInAppMessageButtonLayoutTypeStacked:
            view = [[bundle loadNibNamed:nibName owner:nil options:nil] objectAtIndex:2];
            break;
    }

    [view configureWithButtons:buttons
                        layout:layout
                         style:style
                        target:target
                      selector:selector];

    return view;
}

- (void)configureWithButtons:(NSArray<UAInAppMessageButtonInfo *> *)buttons
                         layout:(UAInAppMessageButtonLayoutType)layout
                          style:(UAInAppMessageButtonStyle *)style
                         target:(id)target
                       selector:(SEL)selector {

    switch (layout) {
        case UAInAppMessageButtonLayoutTypeJoined:
            break;
        case UAInAppMessageButtonLayoutTypeSeparate:
            // Set button spacing style
            if (self) {
                self.buttonContainer.spacing = style.separatedButtonSpacing ? [style.separatedButtonSpacing floatValue] : DefaultSeparatedButtonSpacing;
            }

            break;
        case UAInAppMessageButtonLayoutTypeStacked:
            // Set button spacing style
            if (self) {
                self.buttonContainer.spacing = style.stackedButtonSpacing ? [style.stackedButtonSpacing floatValue] : DefaultStackedButtonSpacing;
            }

            break;
    }

    self.style = style;

    self.translatesAutoresizingMaskIntoConstraints = NO;
    [self addButtons:buttons layout:layout target:target selector:selector];

    // Add the button style padding
    [UAInAppMessageUtils applyPaddingToView:self.buttonContainer padding:style.additionalPadding replace:NO];
}

- (void)addButtons:(NSArray<UAInAppMessageButtonInfo *> *)buttonInfos
            layout:(UAInAppMessageButtonLayoutType)layout
            target:(id)target
          selector:(SEL)selector {
    if (!self.buttonContainer) {
        UA_LDEBUG(@"Button view container stack is nil");
        return;
    }

    if (!target) {
        UA_LDEBUG(@"Buttons require a target");
        return;
    }

    if (!selector) {
        UA_LDEBUG(@"Buttons require a selector");
        return;
    }

    NSUInteger buttonOrder = 0;
    CGFloat maxButtonHeight = 0;
    NSMutableArray<UAInAppMessageButton *> *buttons = [NSMutableArray array];
    
    for (UAInAppMessageButtonInfo *buttonInfo in buttonInfos) {
        UAInAppMessageButton *button;

        // This rounds to the desired border radius which is 0 by default
        NSUInteger rounding = UAInAppMessageButtonRoundingOptionAllCorners;
        if (layout == UAInAppMessageButtonLayoutTypeJoined && buttonInfos.count > 1) {
            if (buttonOrder == 0) {
                rounding = UAInAppMessageButtonRoundingTopLeftCorner | UAInAppMessageButtonRoundingBottomLeftCorner;
            }
            if (buttonOrder == 1) {
                rounding = UAInAppMessageButtonRoundingTopRightCorner | UAInAppMessageButtonRoundingBottomRightCorner;
            }
        }

        button = [UAInAppMessageButton buttonWithButtonInfo:buttonInfo
                                                      style:self.style
                                                   rounding:rounding];
        
        [button addTarget:target action:selector forControlEvents:UIControlEventTouchUpInside];

        button.backgroundColor = buttonInfo.backgroundColor;

        [self.buttonContainer addArrangedSubview:button];
        buttonOrder++;

        maxButtonHeight = MAX(maxButtonHeight,button.heightConstraint.constant);
        [buttons addObject:button];
    }
    
    // Apply the button style height or default to tallest button height
    for (UAInAppMessageButton *button in buttons) {
        button.heightConstraint.constant = self.style.buttonHeight ? [self.style.buttonHeight floatValue] : maxButtonHeight;
    }

    if (self.buttonContainer.subviews.count == 0) {
        [self.buttonContainer removeFromSuperview];
    }

    [self.buttonContainer layoutIfNeeded];
}

@end
