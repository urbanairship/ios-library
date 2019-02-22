/* Copyright Urban Airship and Contributors */

#import "UAInAppMessageResizableViewController+Internal.h"
#import "UAirship.h"
#import "UAViewUtils+Internal.h"
#import "UAInAppMessageResolution.h"
#import "UAInAppMessageUtils+Internal.h"
#import "UAInAppMessageModalViewController+Internal.h"
#import "UAInAppMessageHTMLViewController+Internal.h"
#import "UAInAppMessageResolution.h"

/*
 * Hand tuned value that removes excess vertical safe area to make the
 * top padding look more consistent with the iPhone X nub
 */
CGFloat const ResizingViewExcessiveSafeAreaPadding = -8;

/**
 * The in-app message resizing view interface necessary for rounded corners.
 */
@interface UAInAppMessageResizableView : UIView

/**
 * The resizing container view's border radius in points.
 */
@property (nonatomic, assign) CGFloat borderRadius;

/**
 * The flag that tells the view whether or not to round its border.
 */
@property (nonatomic, assign) BOOL allowBorderRounding;

@end

/**
 * The in-app message resizing view implementation necessary for rounded corners.
 */
@implementation UAInAppMessageResizableView

- (void)layoutSubviews {
    [super layoutSubviews];

    [self applyBorderRounding];
}

- (void)applyBorderRounding {
    if (!self.allowBorderRounding) {
        //Don't round if display is full screen
        return;
    }

    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.path = [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                           byRoundingCorners:UIRectCornerAllCorners
                                                 cornerRadii:(CGSize){self.borderRadius, self.borderRadius}].CGPath;
    self.layer.mask = maskLayer;
}

@end


/**
 * Resizing view controller that acts as a dynamic container for modal and HTML child views
 */
@interface UAInAppMessageResizableViewController ()

/**
 * The internal container view that holds sub views and can be rounded.
 */
@property (strong, nonatomic) IBOutlet UAInAppMessageResizableView *resizingContainerView;

/**
 * The shade view.
 */
@property (strong, nonatomic) IBOutlet UIView *shadeView;

/**
 * Constraints necessary to deactivate before stretching to full screen
 */
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *maxWidthConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *centerXConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *centerYConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *widthConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *heightConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *containerAspect;

/**
 * The completion handler passed in when the message is shown.
 */
@property (nonatomic, copy, nullable) void (^showCompletionHandler)(UAInAppMessageResolution *);


@end

@implementation UAInAppMessageResizableViewController

double const DefaultResizableViewAnimationDuration = 0.2;

+ (instancetype)resizableViewControllerWithChild:(UIViewController *)vc {
    return [[self alloc] initWithViewController:vc];

}

- (instancetype)initWithViewController:(UIViewController *)vc {
    self = [self initFromNib];

    if (self) {
        [self addChildViewController:vc];
    }

    return self;
}

- (void)addInAppMessageChildViewController:(UIViewController *)child  {
    [self.resizingContainerView addSubview:child.view];
    [UAViewUtils applyContainerConstraintsToContainer:self.resizingContainerView containedView:child.view];
}

-(instancetype)initFromNib {
    return [self initWithNibName:@"UAInAppMessageResizableViewController" bundle:[UAirship resources]];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    if (self.childViewControllers.count > 0) {
        UIViewController *child = self.childViewControllers[0];
        
        [self addInAppMessageChildViewController:child];
        [child didMoveToParentViewController:self];
    }

    self.resizingContainerView.allowBorderRounding = self.allowBorderRounding;
    self.resizingContainerView.backgroundColor = self.backgroundColor;
    self.resizingContainerView.borderRadius = self.borderRadius;

    self.displayFullScreen = self.allowFullScreenDisplay && (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad);

    self.resizingContainerView.allowBorderRounding = !(self.displayFullScreen);

    // will make opaque as part of animation when view appears
    self.view.alpha = 0;
    // disable voiceover interactions with visible items beneath the modal
    self.view.accessibilityViewIsModal = YES;

    if (self.displayFullScreen) {
        // Detect view type
        [self stretchToFullScreen];
        [self refreshViewForCurrentOrientation];
    }

    // Apply max width and height constraints from style if they are present
    if (self.maxWidth) {
        self.maxWidthConstraint.active = NO;

        // Set max width
        [NSLayoutConstraint constraintWithItem:self.resizingContainerView
                                     attribute:NSLayoutAttributeWidth
                                     relatedBy:NSLayoutRelationLessThanOrEqual
                                        toItem:nil
                                     attribute:NSLayoutAttributeNotAnAttribute
                                    multiplier:1
                                      constant:[self.maxWidth floatValue]].active = YES;
    }

    if (self.maxHeight) {
        // Set max height
        [NSLayoutConstraint constraintWithItem:self.resizingContainerView
                                     attribute:NSLayoutAttributeHeight
                                     relatedBy:NSLayoutRelationLessThanOrEqual
                                        toItem:nil
                                     attribute:NSLayoutAttributeNotAnAttribute
                                    multiplier:1
                                      constant:[self.maxHeight floatValue]].active = YES;
    }

    // Add the style padding to the modal itself if not full screen
    if (!self.displayFullScreen) {
        [UAInAppMessageUtils applyPaddingToView:self.resizingContainerView padding:self.additionalPadding replace:NO];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    // fade in resizable message view
    if (self.view.alpha == 0) {
        UA_WEAKIFY(self);
        [UIView animateWithDuration:DefaultResizableViewAnimationDuration animations:^{
            self.view.alpha = 1;

            [self.view setNeedsLayout];
            [self.view layoutIfNeeded];
        } completion:^(BOOL finished) {
            UA_STRONGIFY(self);
            self.isShowing = YES;
            [self refreshViewForCurrentOrientation];
        }];
    }
}

#pragma mark -
#pragma mark Core Functionality

- (void)showWithCompletionHandler:(void (^)(UAInAppMessageResolution * _Nonnull))completionHandler {
    if (self.isShowing) {
        UA_LTRACE(@"In-app message resizable view has already been displayed");
        return;
    }

    self.showCompletionHandler = completionHandler;

    // create a new window that covers the entire display
    self.topWindow = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];

    // make sure window appears above any alerts already showing
    self.topWindow.windowLevel = UIWindowLevelAlert;

    // add this view controller to the window
    self.topWindow.rootViewController = self;

    // show the window
    [self.topWindow makeKeyAndVisible];
}

// Alters contraints to cover the full screen.
- (void)stretchToFullScreen {

    // Deactivate necessary modal constraints
    self.maxWidthConstraint.active = NO;
    self.centerXConstraint.active = NO;
    self.centerYConstraint.active = NO;
    self.widthConstraint.active = NO;
    self.heightConstraint.active = NO;
    self.containerAspect.active = NO;

    // Add full screen constraints
    // (note the these are not to the safe area - so insets will need to be provided opn iPhone X)
    [UAViewUtils applyContainerConstraintsToContainer:self.view containedView:self.resizingContainerView];

    // Set shade view to background colorv
    self.shadeView.opaque = YES;
    self.shadeView.alpha = 1;
    self.shadeView.backgroundColor = self.backgroundColor;
}

- (void)dismissWithResolution:(UAInAppMessageResolution *)resolution {
    UA_WEAKIFY(self);
    [UIView animateWithDuration:DefaultResizableViewAnimationDuration animations:^{
        self.view.alpha = 0;

        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        UA_STRONGIFY(self);
        // teardown
        self.isShowing = NO;
        [self.view removeFromSuperview];
        self.topWindow = nil;

        if (self.showCompletionHandler) {
            self.showCompletionHandler(resolution);
            self.showCompletionHandler = nil;
        }
    }];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [self refreshViewForCurrentOrientation];
}

- (void)refreshViewForCurrentOrientation {
    if (self.displayFullScreen) {
        if (@available(iOS 11.0, *)) {
            UIWindow *window = [UIApplication sharedApplication].keyWindow;
            // Black out the inset and compensate for excess vertical safe area when iPhone X is horizontal
            if (window.safeAreaInsets.top == 0 && window.safeAreaInsets.left > 0) {
                self.shadeView.backgroundColor = [UIColor blackColor];
                // Apply insets for iPhone X, use larger safe inset on rotation to balance the view
                CGFloat largerInset = fmax(window.safeAreaInsets.left, window.safeAreaInsets.right);
                [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeTrailing onView:self.resizingContainerView padding:largerInset replace:YES];
                [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeLeading onView:self.resizingContainerView padding:largerInset replace:YES];
                [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeTop onView:self.resizingContainerView padding:window.safeAreaInsets.top replace:YES];
                [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeBottom onView:self.resizingContainerView padding:window.safeAreaInsets.bottom replace:YES];
            } else if (window.safeAreaInsets.top > 0 && window.safeAreaInsets.left == 0) {
                [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeTrailing onView:self.resizingContainerView padding:0 replace:YES];
                [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeLeading onView:self.resizingContainerView padding:0 replace:YES];
                [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeTop onView:self.resizingContainerView padding:window.safeAreaInsets.top + ResizingViewExcessiveSafeAreaPadding replace:YES];
                [UAInAppMessageUtils applyPaddingForAttribute:NSLayoutAttributeBottom onView:self.resizingContainerView padding:window.safeAreaInsets.bottom replace:YES];
                self.shadeView.backgroundColor = self.backgroundColor;
            }
        }
    }
}


@end
