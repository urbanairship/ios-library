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

#import "UAInAppMessageController.h"
#import "UAInAppMessage.h"
#import "UAUtils.h"
#import "UAInAppMessageButtonActionBinding.h"
#import "UAActionRunner+Internal.h"
#import "UAirship.h"
#import "UAInAppMessaging.h"
#import "UAInAppResolutionEvent.h"
#import "UAirship.h"
#import "UAAnalytics.h"
#import "UAInAppMessageControllerDefaultDelegate.h"

#define kUAInAppMessageMinimumLongPressDuration 0.2

@interface UAInAppMessageController ()

@property(nonatomic, strong) UAInAppMessage *message;
@property(nonatomic, strong) UIView *messageView;
@property(nonatomic, copy) void (^dismissalBlock)(void);
@property(nonatomic, strong) NSDate *startDisplayDate;
@property(nonatomic, strong) id<UAInAppMessageControllerDelegate> userDelegate;
@property(nonatomic, strong) UAInAppMessageControllerDefaultDelegate *defaultDelegate;

/**
 * A timer set for the duration of the message, after wich the view is dismissed.
 */
@property(nonatomic, strong) NSTimer *dismissalTimer;

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

- (instancetype)initWithMessage:(UAInAppMessage *)message
                       delegate:(id<UAInAppMessageControllerDelegate>)delegate
                 dismissalBlock:(void (^)(void))dismissalBlock {

    self = [super init];
    if (self) {
        self.message = message;
        self.buttonActionBindings = message.buttonActionBindings;
        self.userDelegate = delegate;
        self.defaultDelegate = [[UAInAppMessageControllerDefaultDelegate alloc] initWithMessage:message];
        self.dismissalBlock = dismissalBlock;
    }
    return self;
}

+ (instancetype)controllerWithMessage:(UAInAppMessage *)message
                             delegate:(id<UAInAppMessageControllerDelegate>)delegate
                       dismissalBlock:(void(^)(void))dismissalBlock {

    return [[self alloc] initWithMessage:message delegate:delegate dismissalBlock:dismissalBlock];
}

// Delegate helper methods

- (UIView *)messageViewWithParentView:(UIView *)parentView {
    if ([self.userDelegate respondsToSelector:@selector(viewForMessage:parentView:)]) {
        return [self.userDelegate viewForMessage:self.message parentView:parentView];
    } else {
        return [self.defaultDelegate viewForMessage:self.message parentView:parentView];
    }
}

- (UIControl *)buttonAtIndex:(NSUInteger)index {
    if ([self.userDelegate respondsToSelector:@selector(messageView:buttonAtIndex:)]) {
        return [self.userDelegate messageView:self.messageView buttonAtIndex:index];
    } else {
        return [self.defaultDelegate messageView:self.messageView buttonAtIndex:index];
    }
}


// Optional delegate methods
- (void)handleTouchState:(BOOL)touchDown {
    // Only call our default delegate if the user delegate is not set, as our handling of touch state
    // will not work universally.
    if (self.userDelegate) {
        if ([self.userDelegate respondsToSelector:@selector(messageView:didChangeTouchState:)]) {
            [self.userDelegate messageView:self.messageView didChangeTouchState:touchDown];
        }
    } else {
        [self.defaultDelegate messageView:self.messageView didChangeTouchState:touchDown];
    }
}

- (void)animateInWithParentView:(UIView *)parentView completionHandler:(void (^)(void))completionHandler {
    if ([self.userDelegate respondsToSelector:@selector(messageView:animateInWithParentView:completionHandler:)]) {
        [self.userDelegate messageView:self.messageView animateInWithParentView:parentView completionHandler:completionHandler];
    } else {
        [self.defaultDelegate messageView:self.messageView animateInWithParentView:parentView completionHandler:completionHandler];
    }
}

- (void)animateOutWithParentView:(UIView *)parentView completionHandler:(void (^)(void))completionHandler {
    if ([self.userDelegate respondsToSelector:@selector(messageView:animateOutWithParentView:completionHandler:)]) {
        [self.userDelegate messageView:self.messageView animateOutWithParentView:parentView completionHandler:completionHandler];
    } else {
        [self.defaultDelegate messageView:self.messageView animateOutWithParentView:parentView completionHandler:completionHandler];
    }
}

/**
 * Signs self up for control events on the message view.
 * This method has the side effect of adding self as a target for
 * button, swipe and tap actions.
 */
- (void)signUpForControlEventsWithMessageView:(UIView *)messageView {
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
        tapGestureRecognizer.delegate = self;
        [messageView addGestureRecognizer:tapGestureRecognizer];


        UILongPressGestureRecognizer *longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressWithGestureRecognizer:)];
        longPressGestureRecognizer.minimumPressDuration = kUAInAppMessageMinimumLongPressDuration;
        longPressGestureRecognizer.delegate = self;
        [messageView addGestureRecognizer:longPressGestureRecognizer];
    }

    UIControl *button1 = [self buttonAtIndex:0];
    UIControl *button2 = [self buttonAtIndex:1];

    // sign up for button touch events
    [button1 addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [button2 addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)scheduleDismissalTimer {
    self.dismissalTimer = [NSTimer timerWithTimeInterval:self.message.duration
                                                  target:self
                                                selector:@selector(timedOut)
                                                userInfo:nil
                                                 repeats:NO];
    [[NSRunLoop currentRunLoop] addTimer:self.dismissalTimer forMode:NSDefaultRunLoopMode];
}

- (void)invalidateDismissalTimer {
    [self.dismissalTimer invalidate];
}

- (void)listenForAppStateTransitions {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:[UIApplication sharedApplication]];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:[UIApplication sharedApplication]];
}

- (void)resignAppStateTransitions {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)show {

    UIView *parentView = [UAUtils topController].view;

    // retain self for the duration of the message display, so that avoiding premature deallocation
    // is not directly dependent on arbitrary container/object lifecycles
    self.referenceToSelf = self;

    UIView *messageView = [self messageViewWithParentView:parentView];

    // force a layout in case autolayout is used, so that the view's geometry is defined
    [messageView layoutIfNeeded];

    self.messageView = messageView;

    [self signUpForControlEventsWithMessageView:messageView];

    // animate the message view into place, starting the timer when the animation has completed
    [self animateInWithParentView:parentView completionHandler:^{
        [self listenForAppStateTransitions];
        [self scheduleDismissalTimer];
        self.startDisplayDate = [NSDate date];
    }];
}

- (void)dismissWithRunloopDelay {
    // dispatch with a delay of zero to postpone the block by a runloop cycle, so that
    // the animation isn't disrupted
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self animateOutWithParentView:self.messageView.superview completionHandler:^{
            [self.messageView removeFromSuperview];

            self.messageView = nil;
            // release self
            self.referenceToSelf = nil;

            if (self.dismissalBlock) {
                self.dismissalBlock();
            }
        }];
    });
}

- (void)dismiss {
    [self.dismissalTimer invalidate];
    self.dismissalTimer = nil;

    [self resignAppStateTransitions];
    [self dismissWithRunloopDelay];
}

- (void)applicationDidBecomeActive {
    [self scheduleDismissalTimer];
    self.startDisplayDate = [NSDate date];
}

- (void)applicationWillResignActive {
    [self invalidateDismissalTimer];
}

- (void)swipeWithGestureRecognizer:(UIGestureRecognizer *)recognizer {
    [self dismiss];
    UAInAppResolutionEvent *event = [UAInAppResolutionEvent dismissedResolutionWithMessage:self.message
                                                                           displayDuration:[self displayDuration]];
    [[UAirship shared].analytics addEvent:event];
}

/**
 * Called when a message is clicked.
 */
- (void)messageClicked {
    UAInAppResolutionEvent *event = [UAInAppResolutionEvent messageClickedResolutionWithMessage:self.message
                                                                                displayDuration:[self displayDuration]];
    [[UAirship shared].analytics addEvent:event];


    [UAActionRunner runActionsWithActionValues:self.message.onClick
                                     situation:UASituationForegroundInteractiveButton
                                      metadata:nil
                             completionHandler:nil];
}

/**
 * Called when the view times out.
 */
- (void)timedOut {
    [self dismiss];

    UAInAppResolutionEvent *event = [UAInAppResolutionEvent timedOutResolutionWithMessage:self.message
                                                                          displayDuration:[self displayDuration]];
    [[UAirship shared].analytics addEvent:event];
}

/**
 * A tap should result in a brief color inversion (0.1 seconds),
 * running the associated actions, and dismissing the message.
 */
- (void)tapWithGestureRecognizer:(UIGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        [self handleTouchState:YES];
        [self messageClicked];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self handleTouchState:NO];
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
        [self handleTouchState:YES];
    } else if (recognizer.state == UIGestureRecognizerStateChanged) {
        if (CGRectContainsPoint(self.messageView.bounds, touchPoint)) {
            [self handleTouchState:YES];
        } else {
            [self handleTouchState:NO];
        }
    } else if (recognizer.state == UIGestureRecognizerStateEnded) {
        if (CGRectContainsPoint(self.messageView.bounds, touchPoint)) {
            [self handleTouchState:NO];
            [self messageClicked];
            [self dismiss];
        }
    }
}

/**
 * Delegate method for the tap and long press recognizer that rejects touches originating from either
 * of the action buttons.
 */
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    // Ignore touches within the action buttons
    if ([touch.view isKindOfClass:[UIControl class]]) {
        return NO;
    }
    return YES;
}

- (void)buttonTapped:(id)sender {
    UAInAppMessageButtonActionBinding *binding;

    UIControl *button1 = [self buttonAtIndex:0];
    UIControl *button2 = [self buttonAtIndex:1];


    // Retrieve the binding associated with the tapped button
    if ([sender isEqual:button1]) {
        binding = self.buttonActionBindings[0];
    } else if ([sender isEqual:button2])  {
        binding = self.buttonActionBindings[1];
    }

    // Run all the bound actions
    [UAActionRunner runActionsWithActionValues:binding.actions
                                     situation:binding.situation
                                      metadata:nil
                             completionHandler:nil];

    UAInAppResolutionEvent *event = [UAInAppResolutionEvent buttonClickedResolutionWithMessage:self.message
                                                                              buttonIdentifier:binding.identifier
                                                                                   buttonTitle:binding.title
                                                                               displayDuration:[self displayDuration]];
    [[UAirship shared].analytics addEvent:event];
    
    
    [self dismiss];
}

/**
 * Returns the current display duration.
 * @return The current display duration.
 */
- (NSTimeInterval)displayDuration {
    return [[NSDate date] timeIntervalSinceDate:self.startDisplayDate];
}

@end
