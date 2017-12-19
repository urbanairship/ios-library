/* Copyright 2017 Urban Airship and Contributors */

#import "UAirship.h"
#import "UAUtils.h"
#import "UAInAppMessageTextView+Internal.h"
#import "UAInAppMessageButtonView+Internal.h"
#import "UAInAppMessageMediaView+Internal.h"
#import "UAInAppMessageBannerContentView+Internal.h"
#import "UAInAppMessageBannerController+Internal.h"
#import "UAInAppMessageBannerView+Internal.h"
#import "UAInAppMessageUtils+Internal.h"
#import "UAInAppMessageManager+Internal.h"
#import "UAColorUtils+Internal.h"

@class UAInAppMessageTextView;
@class UAInAppMessageButtonView;
@class UAInAppMessageMediaView;
@class UAInAppMessageBannerDisplayContent;

double const MaxWidth = 420;

double const DefaultLeadingEdgeSpace = 10;
double const DefaultTrailingEdgeSpace = 10;

double const DefaultAnimationDuration = 0.2;
double const MinimumLongPressDuration = 0.2;
double const MinimumSwipeVelocity = 100.0;

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
 * The banner image.
 */
@property (nonatomic, strong) UIImage *image;

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
@property (nonatomic, copy, nullable) void (^showCompletionHandler)(void);

/**
 * Flag representing the display state of the banner.
 */
@property(nonatomic, assign) BOOL isShown;

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
                                              image:(UIImage * _Nullable)image {

    return [[self alloc] initWithBannerMessageID:messageID
                                  displayContent:displayContent
                                           image:image];
}

- (instancetype)initWithBannerMessageID:(NSString *)messageID
                         displayContent:(UAInAppMessageBannerDisplayContent *)displayContent
                                  image:(UIImage *)image {
    self = [super init];

    if (self) {
        self.messageID = messageID;
        self.displayContent = displayContent;
        self.image = image;
    }

    return self;
}

#pragma mark -
#pragma mark Core Functionality

- (void)show:(void (^)(void))completionHandler  {
    if (self.isShown) {
        UA_LDEBUG(@"In-app message banner has already been displayed");

        completionHandler();
    }

    UIView *parentView = [UAUtils mainWindow];
    NSString *placement = self.displayContent.placement;

    UAInAppMessageTextInfo *heading = self.displayContent.heading;
    UAInAppMessageTextInfo *body = self.displayContent.body;
    NSString *contentLayout = self.displayContent.contentLayout;

    NSArray<UAInAppMessageButtonInfo *> *buttons = self.displayContent.buttons;
    NSString *buttonLayout = self.displayContent.buttonLayout;
    UIColor *dismissColor = [UAColorUtils colorWithHexString:self.displayContent.dismissButtonColor];

    if (!parentView) {
        UA_LDEBUG(@"Unable to find parent view, canceling in-app message banner display");
        completionHandler();
    }

    UAInAppMessageTextView *textView = [UAInAppMessageTextView textViewWithHeading:heading
                                                                              body:body];

    UAInAppMessageBannerContentView *bannerContentView = [UAInAppMessageBannerContentView contentViewWithLayout:contentLayout
                                                                                                       textView:textView
                                                                                                          image:self.image];

    UAInAppMessageButtonView *buttonView = [UAInAppMessageButtonView buttonViewWithButtons:buttons
                                                                                    layout:buttonLayout
                                                                                    target:self
                                                                                  selector:@selector(buttonTapped:)
                                                                        dismissButtonColor:dismissColor];

    self.bannerView = [UAInAppMessageBannerView bannerMessageViewWithDisplayContent:self.displayContent
                                                                  bannerContentView:bannerContentView
                                                                         buttonView:buttonView];

    [parentView addSubview:self.bannerView];

    [self addInitialConstraintsToParentView:parentView
                                 bannerView:self.bannerView
                                  placement:placement];

    self.showCompletionHandler = completionHandler;

    [self bannerView:self.bannerView animateInWithParentView:parentView completionHandler:^{
        [self scheduleDismissalTimer];
        [self observeAppState];
        self.isShown = YES;
    }];

    [self initializeGestureRecognizersWithBannerView:self.bannerView parentView:parentView];
}

- (void)dismiss  {

    if (self.showCompletionHandler) {
        self.showCompletionHandler();
        self.showCompletionHandler = nil;
    }

    [self beginTeardown];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self bannerView:self.bannerView animateOutWithParentView:self.bannerView.superview completionHandler:^{
            [self finishTeardown];
        }];
    });
}

- (void)messageTapped {
    self.bannerView.isBeingTapped = NO;
    // TODO Run actions
    [self dismiss];
}

- (void)messageSwiped {
    [self dismiss];
}

- (void)buttonTapped:(id)sender {
    UAInAppMessageButton *button = (UAInAppMessageButton *)sender;

    //TODO Run actions for button info utils method

    // Check button behavior
    if ([button.buttonInfo.behavior isEqualToString:UAInAppMessageButtonInfoBehaviorCancel]) {
        // Cancel IAM schedule
        [[UAirship inAppMessageManager] cancelMessageWithID:self.messageID];
    }

    [self dismiss];
}

#pragma mark -
#pragma mark Autolayout and Animation

- (void)addInitialConstraintsToParentView:(UIView *)parentView
                               bannerView:(UAInAppMessageBannerView *)bannerView
                                placement:(NSString *)placement {

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
                                                               attribute:NSLayoutAttributeLeadingMargin
                                                              multiplier:1
                                                                constant:DefaultLeadingEdgeSpace];
    leading.priority = UILayoutPriorityDefaultHigh;
    leading.active = YES;

    // Constrain Trailing edge
    NSLayoutConstraint *trailing = [NSLayoutConstraint constraintWithItem:bannerView
                                                                attribute:NSLayoutAttributeTrailing
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:parentView
                                                                attribute:NSLayoutAttributeTrailingMargin
                                                               multiplier:1
                                                                 constant:-DefaultTrailingEdgeSpace];
    trailing.priority = UILayoutPriorityDefaultHigh;
    trailing.active = YES;

    // Set max width
    NSLayoutConstraint *maxWidth = [NSLayoutConstraint constraintWithItem:bannerView
                                                                attribute:NSLayoutAttributeWidth
                                                                relatedBy:NSLayoutRelationLessThanOrEqual
                                                                   toItem:nil
                                                                attribute:NSLayoutAttributeNotAnAttribute
                                                               multiplier:1
                                                                 constant:MaxWidth];
    maxWidth.priority = UILayoutPriorityRequired;
    maxWidth.active = YES;

    if ([placement isEqualToString:UAInAppMessageBannerPlacementTop]) {
        // Top constraint is used for animating the message in the top position.
        self.verticalConstraint = [NSLayoutConstraint constraintWithItem:bannerView
                                                               attribute:NSLayoutAttributeTop
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:parentView
                                                               attribute:NSLayoutAttributeTop
                                                              multiplier:1
                                                                constant:-bannerView.bounds.size.height];
    } else if ([placement isEqualToString:UAInAppMessageBannerPlacementBottom]) {
        // Bottom constraint is used for animating the message in the bottom position.
        self.verticalConstraint = [NSLayoutConstraint constraintWithItem:bannerView
                                                               attribute:NSLayoutAttributeBottom
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:parentView
                                                               attribute:NSLayoutAttributeBottom
                                                              multiplier:1
                                                                constant:bannerView.bounds.size.height];
    }

    self.verticalConstraint.active = YES;

    [parentView layoutIfNeeded];
    [bannerView layoutIfNeeded];
}

- (void)bannerView:(UAInAppMessageBannerView *)bannerView animateInWithParentView:(UIView *)parentView completionHandler:(void (^)(void))completionHandler {
    self.verticalConstraint.constant = 0;

    [UIView animateWithDuration:DefaultAnimationDuration delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        [parentView layoutIfNeeded];
        [bannerView layoutIfNeeded];
    } completion:^(BOOL finished) {
        completionHandler();
    }];
}

- (void)bannerView:(UAInAppMessageBannerView *)bannerView animateOutWithParentView:(UIView *)parentView completionHandler:(void (^)(void))completionHandler {
    if ([self.displayContent.placement isEqualToString:UAInAppMessageBannerPlacementTop]) {
        self.verticalConstraint.constant = -bannerView.bounds.size.height;
    } else if ([self.displayContent.placement isEqualToString:UAInAppMessageBannerPlacementBottom]) {
        self.verticalConstraint.constant = bannerView.bounds.size.height;
    }

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

    NSString *placement = self.displayContent.placement;

    CGPoint velocity = [recognizer velocityInView:self.bannerView.superview];
    CGPoint translation = [recognizer translationInView:self.bannerView.superview];

    CGPoint touchPoint = [recognizer locationInView:self.bannerView];
    BOOL touchIsOutOfBannerBounds = !CGRectContainsPoint(self.bannerView.bounds, touchPoint);

    CGFloat absoluteVelocityX = fabs(velocity.x);
    CGFloat absoluteVelocityY = fabs(velocity.y);

    BOOL yVelocityBelowThreshold = absoluteVelocityY < MinimumSwipeVelocity;
    BOOL xVelocityExceedsYVelocity = absoluteVelocityY < absoluteVelocityX;

    BOOL bannerHasTopPlacement = [placement isEqualToString:UAInAppMessageBannerPlacementTop];
    BOOL bannerHasBottomPlacement = [placement isEqualToString:UAInAppMessageBannerPlacementBottom];
    BOOL swipeIsAwayFromBannerPlacement = (translation.y < 0 && bannerHasBottomPlacement) ||
    (translation.y > 0 && bannerHasTopPlacement);


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

#pragma mark -
#pragma mark App State

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
    NSTimeInterval timeInterval = ((double)self.displayContent.duration / 1000);

    self.dismissalTimer = [NSTimer scheduledTimerWithTimeInterval:timeInterval
                                                           target:self
                                                         selector:@selector(dismiss)
                                                         userInfo:nil
                                                          repeats:NO];
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
