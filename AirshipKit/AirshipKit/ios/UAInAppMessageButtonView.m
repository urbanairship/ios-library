/* Copyright 2018 Urban Airship and Contributors */

#import "UAirship.h"
#import "UAInAppMessageButtonView+Internal.h"
#import "UAColorUtils+Internal.h"
#import "UAInAppMessageUtils+Internal.h"
#import "UAInAppMessageBannerDisplayContent.h"
#import "UAInAppMessageButton+Internal.h"
#import "UAColorUtils+Internal.h"

// UAInAppMessageButtonView nib name
NSString *const UAInAppMessageButtonViewNibName = @"UAInAppMessageButtonView";

@interface UAInAppMessageButtonView ()

@property (strong, nonatomic) IBOutlet UIStackView *buttonContainer;

@end

@implementation UAInAppMessageButtonView

+ (instancetype)buttonViewWithButtons:(NSArray<UAInAppMessageButtonInfo *> *)buttons
                               layout:(UAInAppMessageButtonLayoutType)layout
                               target:(id)target
                             selector:(SEL)selector {
    return [[UAInAppMessageButtonView alloc] initWithButtons:buttons
                                                      layout:layout
                                                      target:target
                                                    selector:selector];
}

- (instancetype)initWithButtons:(NSArray<UAInAppMessageButtonInfo *> *)buttons
                         layout:(UAInAppMessageButtonLayoutType)layout
                         target:(id)target
                       selector:(SEL)selector {

    self = [super init];

    NSString *nibName = UAInAppMessageButtonViewNibName;
    NSBundle *bundle = [UAirship resources];
    UAInAppMessageButtonView *view;
    
    // Joined, Separate and Stacked views object at index 0,1,2, respectively.
    switch (layout) {
        case UAInAppMessageButtonLayoutTypeJoined:
            view = [[bundle loadNibNamed:nibName owner:target options:nil] objectAtIndex:0];
            break;
        case UAInAppMessageButtonLayoutTypeSeparate:
            view = [[bundle loadNibNamed:nibName owner:target options:nil] objectAtIndex:1];
            break;
        case UAInAppMessageButtonLayoutTypeStacked:
            view = [[bundle loadNibNamed:nibName owner:target options:nil] objectAtIndex:2];
            break;
    }

    if (view) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [view addButtons:buttons layout:layout target:target selector:selector];
    }

    return view;

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
                                                   rounding:rounding];
        
        [button addTarget:target action:selector forControlEvents:UIControlEventTouchUpInside];

        button.backgroundColor = buttonInfo.backgroundColor;

        [self.buttonContainer addArrangedSubview:button];
        buttonOrder++;

        maxButtonHeight = MAX(maxButtonHeight,button.heightConstraint.constant);
        [buttons addObject:button];
    }
    
    // make all the buttons the same height as the tallest button
    for (UAInAppMessageButton *button in buttons) {
        button.heightConstraint.constant = maxButtonHeight;
    }

    if (self.buttonContainer.subviews.count == 0) {
        [self.buttonContainer removeFromSuperview];
    }

    [self.buttonContainer layoutIfNeeded];
}

@end
