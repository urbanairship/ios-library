/* Copyright Urban Airship and Contributors */

#import "UAirship.h"
#import "UAUtils+Internal.h"
#import "UAInAppMessageTextView+Internal.h"
#import "UAInAppMessageButtonView+Internal.h"
#import "UAInAppMessageMediaView+Internal.h"
#import "UAInAppMessageBannerContentView+Internal.h"
#import "UAInAppMessageBannerController+Internal.h"
#import "UAInAppMessageBannerView+Internal.h"
#import "UAInAppMessageUtils+Internal.h"
#import "UAInAppMessageManager+Internal.h"
#import "UAColorUtils+Internal.h"
#import "UAActionRunner+Internal.h"
#import "UAInAppMessageBannerStyle.h"

NS_ASSUME_NONNULL_BEGIN

@class UAInAppMessageTextView;
@class UAInAppMessageButtonView;
@class UAInAppMessageMediaView;
@class UAInAppMessageBannerDisplayContent;

double const DefaultMaxWidth = 420;

double const DefaultBannerControllerPadding = 24;

double const DefaultAnimationDuration = 0.2;
double const MinimumLongPressDuration = 0.2;
double const MinimumSwipeVelocity = 100.0;

/*
 * Hand tuned value that removes excess vertical safe area to properly offset the
 * top padding from the nub on the iPhone X
 */
CGFloat const BannerExcessiveSafeAreaPadding = 14;


@interface UAInAppMessageBannerController ()

/**
 * The idenfier of the banner message.
 */
@property (nonatomic, strong) NSString *messageID;

/**
 * The banner display content consisting of the text and image.
 */
@property (nonatomic, strong) UAInAppMessageBannerDisplayContent *displayContent;

/**
 * The in-app message banner view styling.
 */
@property(nonatomic, strong) UAInAppMessageBannerStyle *style;

/**
 * The banner's media view.
 */
@property (nonatomic, strong) UAInAppMessageMediaView *mediaView;

/**
 * The banner view. Contains contentView, buttonsView and textView subviews.
 */
@property (nonatomic, strong) UAInAppMessageBannerView *bannerView;

/**
 * Vertical constraint is used to vertically position the message.
 */
@property (nonatomic, strong) NSLayoutConstraint *verticalConstraint;

/**
 * Pan gesture recognizer.
 */
@property (nonatomic, strong) UIPanGestureRecognizer *panGestureRecognizer;

/**
 * A timer set for the duration of the message, after wich the view is dismissed.
 */
@property(nonatomic, strong) NSTimer *dismissalTimer;

/**
 * The completion handler passed in when the message is shown.
 */
@property (nonatomic, copy, nullable) void (^showCompletionHandler)(UAInAppMessageResolution *);

/**
 * Flag representing the display state of the banner.
 */
@property(nonatomic, assign) BOOL isShowing;

/**
 * Gesture recognizer flags.
 */
@property(nonatomic, assign) BOOL swipeDetected;
@property(nonatomic, assign) BOOL tapDetected;
@property(nonatomic, assign) BOOL longPressDetected;

@end

@implementation UAInAppMessageBannerController

+ (instancetype)bannerControllerWithBannerMessageID:(NSString *)messageID
                                     displayContent:(UAInAppMessageBannerDisplayContent *)displayContent
                                          mediaView:(nullable UAInAppMessageMediaView *)mediaView
                                              style:(nullable UAInAppMessageBannerStyle *)style {

    return [[self alloc] initWithBannerMessageID:messageID
                                  displayContent:displayContent
                                       mediaView:mediaView
                                           style:style];
}

- (instancetype)initWithBannerMessageID:(NSString *)messageID
                         displayContent:(UAInAppMessageBannerDisplayContent *)displayContent
                              mediaView:(nullable UAInAppMessageMediaView *)mediaView
                                  style:(nullable UAInAppMessageBannerStyle *)style {
    self = [super init];

    if (self) {
        self.messageID = messageID;
        self.displayContent = displayContent;
        self.mediaView = mediaView;
        self.style = style;

        [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged:)
                                                     name:UIDeviceOrientationDidChangeNotification
                                                   object:nil];
    }

    return self;
}

#pragma mark -
#pragma mark Core Functionality

- (void)showWithParentView:(UIView *)parentView completionHandler:(void (^)(UAInAppMessageResolution * _Nonnull))completionHandler {
    if (self.isShowing) {
        UA_LTRACE(@"In-app message banner has already been displayed");
        return;
    }

    UAInAppMessageTextInfo *heading = self.displayContent.heading;
    UAInAppMessageTextInfo *body = self.displayContent.body;
    UAInAppMessageBannerContentLayoutType contentLayout = self.displayContent.contentLayout;

    NSArray<UAInAppMessageButtonInfo *> *buttons = self.displayContent.buttons;
    UAInAppMessageButtonLayoutType buttonLayout = self.displayContent.buttonLayout;

    UAInAppMessageTextView *headerView = [UAInAppMessageTextView textViewWithTextInfo:heading style:self.style.headerStyle];
    UAInAppMessageTextView *bodyView = [UAInAppMessageTextView textViewWithTextInfo:body style:self.style.bodyStyle];

    UAInAppMessageBannerContentView *bannerContentView = [UAInAppMessageBannerContentView contentViewWithLayout:contentLayout
                                                                                                     headerView:headerView
                                                                                                       bodyView:bodyView
                                                                                                      mediaView:self.mediaView];


    // Only add button view if buttons are present
    UAInAppMessageButtonView *buttonView;
    if (buttons.count) {
        buttonView = [UAInAppMessageButtonView buttonViewWithButtons:buttons
                                                              layout:buttonLayout
                                                               style:self.style.buttonStyle
                                                              target:self
                                                            selector:@selector(buttonTapped:)];
    }

    self.bannerView = [UAInAppMessageBannerView bannerMessageViewWithDisplayContent:self.displayContent
                                                                  bannerContentView:bannerContentView
                                                                         buttonView:buttonView
                                                                              style:self.style];
    [parentView addSubview:self.bannerView];
    [self addInitialConstraintsToParentView:parentView
                                 bannerView:self.bannerView
                                  placement:self.displayContent.placement];

    // Apply style padding to banner container
    [UAInAppMessageUtils applyPaddingToView:self.bannerView.containerView padding:self.style.additionalPadding replace:NO];

    // Apply style padding to banner text views
    [UAInAppMessageUtils applyPaddingToView:headerView.textLabel padding:self.style.headerStyle.additionalPadding replace:NO];

    // Apply style padding to banner button view
    [UAInAppMessageUtils applyPaddingToView:buttonView.buttonContainer padding:self.style.buttonStyle.additionalPadding replace:NO];

    // Apply style padding to banner button view
    [UAInAppMessageUtils applyPaddingToView:self.mediaView.mediaContainer padding:self.style.mediaStyle.additionalPadding replace:NO];

    self.showCompletionHandler = completionHandler;

    [self bannerView:self.bannerView animateInWithParentView:parentView completionHandler:^{
        [self scheduleDismissalTimer];
        [self observeAppState];
        self.isShowing = YES;
    }];

    [self initializeGestureRecognizersWithBannerView:self.bannerView parentView:parentView];
}

- (void)dismissWithResolution:(UAInAppMessageResolution *)resolution  {
    [self beginTeardown];

    [[UADispatcher mainDispatcher] dispatchAsync:^{
        [self bannerView:self.bannerView animateOutWithParentView:self.bannerView.superview completionHandler:^{
            [self finishTeardown];

            if (self.showCompletionHandler) {
                self.showCompletionHandler(resolution);
                self.showCompletionHandler = nil;
            }            
        }];
    }];
}

- (void)messageTapped {
    self.bannerView.isBeingTapped = NO;

    if (self.displayContent.actions) {
        [UAActionRunner runActionsWithActionValues:self.displayContent.actions
                                         situation:UASituationManualInvocation
                                          metadata:nil
                                 completionHandler:^(UAActionResult *result) {
                                     UA_LTRACE(@"Message tap actions finished running.");
                                 }];
    }

    [self dismissWithResolution:[UAInAppMessageResolution messageClickResolution]];
}

- (void)messageSwiped {
    [self dismissWithResolution:[UAInAppMessageResolution userDismissedResolution]];
}

- (void)buttonTapped:(id)sender {
    UAInAppMessageButton *button = (UAInAppMessageButton *)sender;
    [UAInAppMessageUtils runActionsForButton:button];
    [self dismissWithResolution:[UAInAppMessageResolution buttonClickResolutionWithButtonInfo:button.buttonInfo]];
}

#pragma mark -
#pragma mark Autolayout and Animation

- (void)addInitialConstraintsToParentView:(UIView *)parentView
                               bannerView:(UAInAppMessageBannerView *)bannerView
                                placement:(UAInAppMessageBannerPlacementType)placement {

    // Center on X axis
    [NSLayoutConstraint constraintWithItem:bannerView
                                 attribute:NSLayoutAttributeCenterX
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:parentView
                                 attribute:NSLayoutAttributeCenterX
                                multiplier:1
                                  constant:0].active = YES;

    // Constrain leading edge
    NSLayoutConstraint *leading = [NSLayoutConstraint constraintWithItem:bannerView
                                                               attribute:NSLayoutAttributeLeading
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:parentView
                                                               attribute:NSLayoutAttributeLeading
                                                              multiplier:1
                                                                constant:DefaultBannerControllerPadding];
    // High but can still be broken by max width
    leading.priority = 999;
    leading.active = YES;

    // Constrain Trailing edge
    NSLayoutConstraint *trailing = [NSLayoutConstraint constraintWithItem:parentView
                                                                attribute:NSLayoutAttributeTrailing
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:bannerView
                                                                attribute:NSLayoutAttributeTrailing
                                                               multiplier:1
                                                                 constant:DefaultBannerControllerPadding];
    // High but can still be broken by max width
    trailing.priority = 999;
    trailing.active = YES;

    // Set max width
    NSLayoutConstraint *maxWidth = [NSLayoutConstraint constraintWithItem:bannerView
                                                                attribute:NSLayoutAttributeWidth
                                                                relatedBy:NSLayoutRelationLessThanOrEqual
                                                                   toItem:nil
                                                                attribute:NSLayoutAttributeNotAnAttribute
                                                               multiplier:1
                                                                 constant:[self.style.maxWidth floatValue] ?: DefaultMaxWidth];
    maxWidth.priority = UILayoutPriorityRequired;
    maxWidth.active = YES;

    switch (placement) {
        case UAInAppMessageBannerPlacementTop:
            // Top constraint is used for animating the message in the top position.
            self.verticalConstraint = [NSLayoutConstraint constraintWithItem:parentView
                                                                   attribute:NSLayoutAttributeTop
                                                                   relatedBy:NSLayoutRelationEqual
                                                                      toItem:bannerView
                                                                   attribute:NSLayoutAttributeTop
                                                                  multiplier:1
                                                                    constant:bannerView.bounds.size.height];

            break;
        case UAInAppMessageBannerPlacementBottom:
            // Bottom constraint is used for animating the message in the bottom position.
            self.verticalConstraint = [NSLayoutConstraint constraintWithItem:bannerView
                                                                   attribute:NSLayoutAttributeBottom
                                                                   relatedBy:NSLayoutRelationEqual
                                                                      toItem:parentView
                                                                   attribute:NSLayoutAttributeBottom
                                                                  multiplier:1
                                                                    constant:bannerView.bounds.size.height];

            break;
    }



    self.verticalConstraint.active = YES;

    [parentView layoutIfNeeded];
    [bannerView layoutIfNeeded];
}

- (void)bannerView:(UAInAppMessageBannerView *)bannerView animateInWithParentView:(UIView *)parentView completionHandler:(void (^)(void))completionHandler {
    self.verticalConstraint.constant = 0;

    // Force orientation check on display
    [self refreshViewForCurrentOrientation];

    [UIView animateWithDuration:DefaultAnimationDuration delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        [parentView layoutIfNeeded];
        [bannerView layoutIfNeeded];
    } completion:^(BOOL finished) {
        completionHandler();
    }];
}

- (void)bannerView:(UAInAppMessageBannerView *)bannerView animateOutWithParentView:(UIView *)parentView completionHandler:(void (^)(void))completionHandler {
    self.verticalConstraint.constant = bannerView.bounds.size.height;

    [UIView animateWithDuration:DefaultAnimationDuration delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        [parentView layoutIfNeeded];
        [bannerView layoutIfNeeded];
    } completion:^(BOOL finished){
        completionHandler();
    }];
}

#pragma mark -
#pragma mark Gesture Recognition

- (void)initializeGestureRecognizersWithBannerView:(UAInAppMessageBannerView *)bannerView parentView:(UIView *)parentView {
    self.panGestureRecognizer  = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                         action:@selector(panWithGestureRecognizer:)];

    self.panGestureRecognizer.delaysTouchesBegan = NO;
    self.panGestureRecognizer.delaysTouchesEnded = NO;
    self.panGestureRecognizer.cancelsTouchesInView = NO;


    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                           action:@selector(tapWithGestureRecognizer:)];
    tapGestureRecognizer.delegate = self;


    UILongPressGestureRecognizer *longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                                                             action:@selector(longPressWithGestureRecognizer:)];
    longPressGestureRecognizer.minimumPressDuration = MinimumLongPressDuration;
    longPressGestureRecognizer.delegate = self;


    [parentView addGestureRecognizer:self.panGestureRecognizer];
    [bannerView addGestureRecognizer:tapGestureRecognizer];
    [bannerView addGestureRecognizer:longPressGestureRecognizer];
}

- (void)panWithGestureRecognizer:(UIPanGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateEnded) {
        return;
    }

    CGPoint velocity = [recognizer velocityInView:self.bannerView.superview];
    CGPoint translation = [recognizer translationInView:self.bannerView.superview];

    CGPoint touchPoint = [recognizer locationInView:self.bannerView];
    BOOL touchIsOutOfBannerBounds = !CGRectContainsPoint(self.bannerView.bounds, touchPoint);

    CGFloat absoluteVelocityX = fabs(velocity.x);
    CGFloat absoluteVelocityY = fabs(velocity.y);

    BOOL yVelocityBelowThreshold = absoluteVelocityY < MinimumSwipeVelocity;
    BOOL xVelocityExceedsYVelocity = absoluteVelocityY < absoluteVelocityX;

    BOOL swipeIsAwayFromBannerPlacement = NO;
    switch (self.displayContent.placement) {
        case UAInAppMessageBannerPlacementTop:
            swipeIsAwayFromBannerPlacement = (translation.y > 0);
            break;
        case UAInAppMessageBannerPlacementBottom:
            swipeIsAwayFromBannerPlacement = (translation.y < 0);
            break;
    }
    if (xVelocityExceedsYVelocity ||  yVelocityBelowThreshold) {
        return;
    }

    if (touchIsOutOfBannerBounds) {
        return;
    }

    if (swipeIsAwayFromBannerPlacement) {
        return;
    }

    if (!self.tapDetected && !self.longPressDetected) {
        self.swipeDetected = YES;
        [self messageSwiped];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    return !([touch.view isKindOfClass:[UIControl class]]);
}

- (void)tapWithGestureRecognizer:(UIGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateEnded) {
        return;
    }

    if (!self.swipeDetected && !self.longPressDetected) {
        self.tapDetected = YES;
        self.bannerView.isBeingTapped = YES;

        [self messageTapped];
    }
}

- (void)longPressWithGestureRecognizer:(UIGestureRecognizer *)recognizer {
    CGPoint touchPoint = [recognizer locationInView:self.bannerView];
    BOOL touchInBounds = CGRectContainsPoint(self.bannerView.bounds, touchPoint);

    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan:
            self.bannerView.isBeingTapped = YES;
            break;
        case UIGestureRecognizerStateChanged:
            if (touchInBounds) {
                self.bannerView.isBeingTapped = YES;
                break;
            }
            self.bannerView.isBeingTapped = NO;
            break;
        case UIGestureRecognizerStateEnded:
            if (touchInBounds && !self.swipeDetected && !self.tapDetected) {
                self.longPressDetected = YES;
                // Message tap event for long press occurs immediately after long press ends
                [self messageTapped];
            }
            break;
        default:
            break;
    }
}

- (void)refreshViewForCurrentOrientation {
    BOOL statusBarShowing = !([UIApplication sharedApplication].isStatusBarHidden);
    CGFloat styledDefaultBannerTopPadding = [self.style.additionalPadding.top floatValue] + DefaultBannerControllerPadding;

    if (@available(iOS 11.0, *)) {
        UIWindow *window = [UIApplication sharedApplication].keyWindow;

        // If the orientation has a bar without inset
        if (window.safeAreaInsets.top == 0 && statusBarShowing) {
            [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeTop
                                                   onView:self.bannerView.containerView
                                                  padding:styledDefaultBannerTopPadding
                                                  replace:YES];
            [self.bannerView layoutIfNeeded];
            return;
        }

        // If the orientation has a bar with inset
        if (window.safeAreaInsets.top > 0 && statusBarShowing) {
            CGFloat adjustedDefaultPadding = window.safeAreaInsets.top - BannerExcessiveSafeAreaPadding;
            CGFloat adjustedCustomPadding = adjustedDefaultPadding + [self.style.additionalPadding.top floatValue];

            CGFloat topPadding = self.style.additionalPadding.top ?  adjustedCustomPadding : adjustedDefaultPadding;

            [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeTop
                                                   onView:self.bannerView.containerView
                                                  padding:topPadding
                                                  replace:YES];
            [self.bannerView layoutIfNeeded];
            return;
        }
    } else {
        // If status bar is showing
        if (statusBarShowing) {
            [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeTop
                                                   onView:self.bannerView.containerView
                                                  padding:styledDefaultBannerTopPadding
                                                  replace:YES];
            [self.bannerView layoutIfNeeded];
            return;
        }
    }

    // Otherwise remove top padding
    [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeTop
                                           onView:self.bannerView.containerView
                                          padding:[self.style.additionalPadding.top floatValue]
                                          replace:YES];
    [self.bannerView layoutIfNeeded];
}

#pragma mark -
#pragma mark App State

- (void)orientationChanged:(NSNotification *)notification {
    [self refreshViewForCurrentOrientation];
}

- (void)applicationDidBecomeActive {
    [self scheduleDismissalTimer];

}

- (void)applicationWillResignActive {
    [self.dismissalTimer invalidate];
}

- (void)observeAppState {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:[UIApplication sharedApplication]];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:[UIApplication sharedApplication]];
}

#pragma mark -
#pragma mark Timer

- (void)scheduleDismissalTimer {
    NSTimeInterval timeInterval = ((double)self.displayContent.durationSeconds);

    self.dismissalTimer = [NSTimer scheduledTimerWithTimeInterval:timeInterval
                                                           target:self
                                                         selector:@selector(timerFired)
                                                         userInfo:nil
                                                          repeats:NO];
}

- (void)timerFired {
    [self dismissWithResolution:[UAInAppMessageResolution timedOutResolution]];
}

#pragma mark -
#pragma mark Teardown

/**
 * Releases all resources. This method can be safely called
 * in dealloc as a protection against unexpected early release.
 */
- (void)teardown {
    [self beginTeardown];
    [self finishTeardown];
}

/**
 * Prepares the message view for dismissal by disabling interaction, removing
 * the pan gesture recognizer and releasing resources that can be disposed of
 * prior to starting the dismissal animation.
 */
- (void)beginTeardown {
    self.bannerView.userInteractionEnabled = NO;
    [self.bannerView.superview removeGestureRecognizer:self.panGestureRecognizer];
    [self.dismissalTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

/**
 * Finalizes dismissal by removing the message view from its
 * parent, and releasing the reference to self
 */
- (void)finishTeardown {
    [self.bannerView removeFromSuperview];
}

- (void)dealloc {
    [self teardown];
}

@end

NS_ASSUME_NONNULL_END


