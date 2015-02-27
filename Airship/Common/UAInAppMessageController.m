#import "UAInAppMessageController.h"
#import "UAInAppMessage.h"
#import "UAInAppMessageView.h"
#import "UAUtils.h"
#import "UAInAppMessageButtonActionBinding.h"
#import "UAActionRunner.h"

#define kUAInAppMessageDefaultPrimaryColor [UIColor whiteColor]
#define kUAInAppMessageDefaultSecondaryColor [UIColor colorWithRed:40.0/255 green:40.0/255 blue:40.0/255 alpha:1]
#define kUAInAppMessageiPhoneScreenWidthPercentage 0.95
#define kUAInAppMessagePadScreenWidthPercentage 0.45
#define kUAInAppMessageMinimumLongPressDuration 0.2
#define kUAInAppMessageAnimationDuration 0.2

@interface UAInAppMessageController ()

@property(nonatomic, strong) UAInAppMessage *message;
@property(nonatomic, strong) UAInAppMessageView *messageView;
@property(nonatomic, strong) UIColor *primaryColor;
@property(nonatomic, strong) UIColor *secondaryColor;
@property(nonatomic, assign) BOOL isInverted;

/**
 * An array of dictionaries containing localized button titles and
 * action name/argument value bindings.
 */
@property(nonatomic, strong) NSArray *buttonActionBindings;

/**
 * A settable reference to self, so we can self-retain for the message
 * display duration.
 */
@property(nonatomic, strong) UAInAppMessageController *referenceToSelf;

@end

@implementation UAInAppMessageController

- (instancetype)initWithMessage:(UAInAppMessage *)message {
    self = [super init];
    if (self) {
        self.message = message;

        self.buttonActionBindings = message.buttonActionBindings;

        // the primary and secondary colors aren't set in the model, choose sensible defaults
        self.primaryColor = self.message.primaryColor ?: kUAInAppMessageDefaultPrimaryColor;
        self.secondaryColor = self.message.secondaryColor ?: kUAInAppMessageDefaultSecondaryColor;

        // colors are uninverted to start
        self.isInverted = NO;
    }
    return self;
}

/**
 * Configures primary and secondary colors in the message view, inverting the color
 * scheme if necessary.
 */
- (void)configureColorsWithMessageView:(UAInAppMessageView *)messageView inverted:(BOOL)inverted {

    UIColor *colorA;
    UIColor *colorB;

    if (inverted) {
        colorA = self.secondaryColor;
        colorB = self.primaryColor;
    } else {
        colorA = self.primaryColor;
        colorB = self.secondaryColor;
    }

    messageView.backgroundColor = colorA;

    messageView.tab.backgroundColor = colorB;

    messageView.messageLabel.textColor = colorB;

    [messageView.button1 setTitleColor:colorA forState:UIControlStateNormal];
    [messageView.button2 setTitleColor:colorA forState:UIControlStateNormal];
    messageView.button1.backgroundColor = colorB;
    messageView.button2.backgroundColor = colorB;
}

/**
 * Configures a message view with the associated
 * message model data.
 */
- (UAInAppMessageView *)buildMessageView {

    UIFont *boldFont = [UIFont boldSystemFontOfSize:12];

    UAInAppMessageView *messageView = [[UAInAppMessageView alloc] initWithPosition:self.message.position
                                                                   numberOfButtons:self.buttonActionBindings.count];

    // configure all the subviews
    messageView.messageLabel.text = self.message.alert;
    messageView.messageLabel.numberOfLines = 4;
    messageView.messageLabel.font = boldFont;

    messageView.button1.titleLabel.font = boldFont;
    messageView.button2.titleLabel.font = boldFont;

    if (self.buttonActionBindings.count) {
        UAInAppMessageButtonActionBinding *button1 = self.buttonActionBindings[0];
        [messageView.button1 setTitle:button1.localizedTitle forState:UIControlStateNormal];
        if (self.buttonActionBindings.count > 1) {
            UAInAppMessageButtonActionBinding *button2 = self.buttonActionBindings[1];
            [messageView.button2 setTitle:button2.localizedTitle forState:UIControlStateNormal];
        }
    }

    [self configureColorsWithMessageView:messageView inverted:NO];

    return messageView;
}

/**
 * Signs self up for control events on the message view.
 * This method has the side effect of adding self as a target for
 * button, swipe and tap actions.
 */
- (void)signUpForControlEventsWithMessageView:(UAInAppMessageView *)messageView {
    // add a swipe gesture recognizer corresponding to the position of the message
    UISwipeGestureRecognizer *swipeGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeWithGestureRecognizer:)];

    if (self.message.position == UAInAppMessagePositionTop) {
        swipeGestureRecognizer.direction = UISwipeGestureRecognizerDirectionUp;
    } else {
        swipeGestureRecognizer.direction = UISwipeGestureRecognizerDirectionDown;
    }

    [messageView addGestureRecognizer:swipeGestureRecognizer];

    // add tap and long press gesture recognizers if an onClick action is present in the model
    if (self.message.onClick) {
        UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapWithGestureRecognizer:)];
        [messageView addGestureRecognizer:tapGestureRecognizer];

        UILongPressGestureRecognizer *longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressWithGestureRecognizer:)];
        longPressGestureRecognizer.minimumPressDuration = kUAInAppMessageMinimumLongPressDuration;
        [messageView addGestureRecognizer:longPressGestureRecognizer];
    }

    // sign up for button touch events
    [messageView.button1 addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [messageView.button2 addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
}

/**
 * Adds layout constraints to the message view.
 */
- (void)buildLayoutWithParent:(UIView *)parentView messageView:(UAInAppMessageView *)messageView {
    CGFloat horizontalMargin = 0;
    CGRect screenRect = [UIScreen mainScreen].applicationFrame;
    CGFloat screenWidth = CGRectGetWidth(screenRect);

    // On an iPad, messages are 45% of the fixed screen width in landscape
    CGFloat longWidth = MAX(screenWidth, CGRectGetHeight(screenRect));
    CGFloat actualLongWidth = longWidth * kUAInAppMessagePadScreenWidthPercentage;

    // On a phone, messages are always 95% of current screen width
    horizontalMargin = (screenWidth - screenWidth*kUAInAppMessageiPhoneScreenWidthPercentage)/2.0;

    id metrics = @{@"horizontalMargin":@(horizontalMargin), @"longWidth":@(actualLongWidth)};
    id views = @{@"messageView":messageView};

    [parentView addSubview:messageView];

    // center the message view in the parent (this cannot be expressed in VFL)
    [parentView addConstraint:[NSLayoutConstraint constraintWithItem:messageView
                                                           attribute:NSLayoutAttributeCenterX
                                                           relatedBy:NSLayoutRelationEqual
                                                              toItem:parentView
                                                           attribute:NSLayoutAttributeCenterX multiplier:1
                                                            constant:0]];

    NSString *verticalLayout;
    NSString *horizontalLayout;

    // place the message view flush against the top or bottom of the parent, depending on position
    if (self.message.position == UAInAppMessagePositionBottom) {
        verticalLayout = @"V:[messageView]|";
    } else {
        verticalLayout = @"V:|[messageView]";
    }

    // if the UI idiom is iPad, use the fixed width, otherwise offset it with the horizontal margins
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        horizontalLayout = @"[messageView(longWidth)]";
    } else {
        horizontalLayout = @"H:|-horizontalMargin-[messageView]-horizontalMargin-|";
    }

    for (NSString *expression in @[verticalLayout, horizontalLayout]) {
        [parentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:expression
                                                                           options:0
                                                                           metrics:metrics
                                                                             views:views]];
    }

    // forces a layout, giving the traditional CGGeometry attributes defined values for the
    // current set of constraints
    [messageView layoutIfNeeded];
}

- (void)show {

    UIView *parentView = [UAUtils topController].view;

    // retain self for the duration of the message display, so that avoiding premature deallocation
    // is not directly dependent on arbitrary container/object lifecycles
    self.referenceToSelf = self;

    UAInAppMessageView *messageView = [self buildMessageView];
    [self buildLayoutWithParent:parentView messageView:messageView];
    [self signUpForControlEventsWithMessageView:messageView];

    self.messageView = messageView;

    // simple timer that dispatches a dismiss call after the message duration has been reached
    void(^timeoutBlock)(void) = ^{
        __weak UAInAppMessageController *weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.message.duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [weakSelf dismiss];
        });
    };

    // save and offset the message view's original center point for animation in
    CGPoint originalCenter = self.messageView.center;
    if (self.message.position == UAInAppMessagePositionTop) {
        self.messageView.center = CGPointMake(originalCenter.x, -(CGRectGetHeight(self.messageView.frame)/2));
    } else if (self.message.position == UAInAppMessagePositionBottom) {
        self.messageView.center = CGPointMake(originalCenter.x, CGRectGetHeight(parentView.frame) + CGRectGetHeight(self.messageView.frame)/2);
    }

    // animate the message view into place, starting the timer when the animation has completed
    [UIView animateWithDuration:kUAInAppMessageAnimationDuration delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.messageView.center = originalCenter;
    } completion:^(BOOL finished) {
        timeoutBlock();
    }];
}

- (void)invertColors {
    if (!self.isInverted) {
        [self configureColorsWithMessageView:self.messageView inverted:YES];
        self.isInverted = YES;
    }
}

- (void)uninvertColors {
    if (self.isInverted) {
        [self configureColorsWithMessageView:self.messageView inverted:NO];
        self.isInverted = NO;
    }
}


- (void)dismissWithAnimationBlock:(void(^)(void))block {
    // dispatch with a delay of zero to postpone the block by a runloop cycle, so that
    // the animation isn't disrupted
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:kUAInAppMessageAnimationDuration
                              delay:0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:block
                         completion:^(BOOL finished){
                             [self.messageView removeFromSuperview];
                             self.messageView = nil;
                             // release self
                             self.referenceToSelf = nil;
                         }];
    });
}

- (void)dismiss {
    [self dismissWithAnimationBlock:^{
        // animate the message view back off the screen
        if (self.message.position == UAInAppMessagePositionTop) {
            self.messageView.center = CGPointMake(self.messageView.center.x, -(CGRectGetHeight(self.messageView.frame)));
        } else {
            self.messageView.center = CGPointMake(self.messageView.center.x, self.messageView.center.y + (CGRectGetHeight(self.messageView.frame)));
        }
    }];
}

- (void)swipeWithGestureRecognizer:(UIGestureRecognizer *)recognizer {
    [self dismiss];
}

- (void)runOnClickActions {
    NSDictionary *actions = self.message.onClick;

    for (NSString *name in actions) {
        UAActionArguments *args = [UAActionArguments argumentsWithValue:actions[name] withSituation:UASituationForegroundInteractiveButton];
        [UAActionRunner runActionWithName:name withArguments:args withCompletionHandler:nil];
    }
}

/**
 * A tap should result in a brief color inversion (0.1 seconds),
 * running the associated actions, and dismissing the message.
 */
- (void)tapWithGestureRecognizer:(UIGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        [self invertColors];
        [self runOnClickActions];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self uninvertColors];
            [self dismiss];
        });
    }
}

/**
 * A long press should result in a color inversion as long as the finger
 * remains within the view boundaries (à la UIButton). Actions should only
 * be run (and the message dismissed) if the gesture ends within these boundaries.
 */
- (void)longPressWithGestureRecognizer:(UIGestureRecognizer *)recognizer {

    CGPoint touchPoint = [recognizer locationInView:self.messageView];

    if (recognizer.state == UIGestureRecognizerStateBegan) {
        [self invertColors];
    } else if (recognizer.state == UIGestureRecognizerStateChanged) {
        if (CGRectContainsPoint(self.messageView.bounds, touchPoint)) {
            [self invertColors];
        } else {
            [self uninvertColors];
        }
    } else if (recognizer.state == UIGestureRecognizerStateEnded) {
        if (CGRectContainsPoint(self.messageView.bounds, touchPoint)) {
            [self uninvertColors];
            [self runOnClickActions];
            [self dismiss];
        }
    }
}

- (void)buttonTapped:(id)sender {
    UAInAppMessageButtonActionBinding *binding;

    // retrieve the binding associated with the tapped button
    if ([sender isEqual:self.messageView.button1]) {
        binding = self.buttonActionBindings[0];
    } else if ([sender isEqual:self.messageView.button2])  {
        binding = self.buttonActionBindings[1];
    }

    // run all the bound actions
    [UAActionRunner runActions:binding.actions withCompletionHandler:nil];

    [self dismiss];
}

@end
