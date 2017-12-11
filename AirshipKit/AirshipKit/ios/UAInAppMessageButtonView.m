/* Copyright 2017 Urban Airship and Contributors */

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
@property(nonatomic, strong) NSString *buttonLayout;
@property (strong, nonatomic) IBOutlet UIStackView *buttonContainer;
@property (strong, nonatomic) UIColor *dismissButtonColor;

@end

@implementation UAInAppMessageButtonView

// I need to add the buttons on init instead of adding them at some point
// after initialization. Doing it the way I'm doing it now makes it so I can't
// determine if there are any buttons which I need to be able to do to minimize
// the button view if there are none. I can probably add a button builder block
// where I define the code that loops through and adds the buttons

//I actually think I can just do this by msaking addButton into addButtons and passing in all the buttons into init


+ (instancetype)buttonViewWithButtons:(NSArray<UAInAppMessageButtonInfo *> *)buttons
                               layout:(NSString *)layout
                               target:(id)target
                             selector:(SEL)selector
                   dismissButtonColor:(UIColor *)dismissColor {
    return [[UAInAppMessageButtonView alloc] initWithButtons:buttons
                                                      layout:layout
                                                      target:target
                                                    selector:selector
                                          dismissButtonColor:dismissColor];
}

- (instancetype)initWithButtons:(NSArray<UAInAppMessageButtonInfo *> *)buttons
                         layout:(NSString *)layout
                         target:(id)target
                       selector:(SEL)selector
             dismissButtonColor:(UIColor *)dismissColor {

    self = [super init];

    NSString *nibName = UAInAppMessageButtonViewNibName;
    NSBundle *bundle = [UAirship resources];

    // Joined, Separate and Stacked views object at index 0,1,2, respectively.
    if ([layout isEqualToString:UAInAppMessageButtonLayoutJoined]) {
        self = [[bundle loadNibNamed:nibName owner:self options:nil] objectAtIndex:0];
    } else if ([layout isEqualToString:UAInAppMessageButtonLayoutSeparate]) {
        self = [[bundle loadNibNamed:nibName owner:self options:nil] objectAtIndex:1];
    } else if ([layout isEqualToString:UAInAppMessageButtonLayoutStacked]) {
        self = [[bundle loadNibNamed:nibName owner:self options:nil] objectAtIndex:2];
    } else {
        UA_LDEBUG(@"Invalid content layout for banner button view");
    }

    if (self) {
        self.dismissButtonColor = dismissColor;
        self.translatesAutoresizingMaskIntoConstraints = NO;
        [self addButtons:buttons layout:layout target:target selector:selector];
    }

    return self;

}

- (void)addButtons:(NSArray<UAInAppMessageButtonInfo *> *)buttons
            layout:layout target:(id)target
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
    for (UAInAppMessageButtonInfo *buttonInfo in buttons) {
        UAInAppMessageButton *button;

        // This rounds to the desired border radius which is 0 by default
        NSUInteger rounding = UAInAppMessageButtonRoundingOptionAllCorners;
        if ([layout isEqualToString:UAInAppMessageButtonLayoutJoined]) {
            if (buttonOrder == 0) {
                rounding = UAInAppMessageButtonRoundingTopLeftCorner | UAInAppMessageButtonRoundingBottomLeftCorner;
            }
            if (buttonOrder == 1) {
                rounding = UAInAppMessageButtonRoundingTopRightCorner | UAInAppMessageButtonRoundingBottomRightCorner;
            }
        }

        button = [UAInAppMessageButton buttonWithButtonInfo:buttonInfo
                                                   rounding:rounding];

        // Probably will move this into UAInAppMessageButtonView
        [UAInAppMessageUtils applyButtonInfo:buttonInfo button:button];
        [button addTarget:target action:selector forControlEvents:UIControlEventTouchUpInside];

        // Customize button background color if it has dismiss behavior, otherwise fall back to button color
        if ([buttonInfo.behavior isEqualToString:UAInAppMessageButtonInfoBehaviorDismiss]) {
            button.backgroundColor = self.dismissButtonColor ?: [UAColorUtils colorWithHexString:buttonInfo.backgroundColor];
        } else {
            button.backgroundColor = [UAColorUtils colorWithHexString:buttonInfo.backgroundColor];
        }

        [self.buttonContainer addArrangedSubview:button];
        [self.buttonContainer layoutIfNeeded];
        buttonOrder++;
    }

    if (self.buttonContainer.subviews.count == 0) {
        [self.buttonContainer removeFromSuperview];
    }
}

@end
