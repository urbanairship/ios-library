/* Copyright Airship and Contributors */

#import "UAInAppMessageResizableViewController+Internal.h"
#import "UAInAppMessageResolution.h"
#import "UAInAppMessageUtils+Internal.h"
#import "UAInAppMessageModalViewController+Internal.h"
#import "UAInAppMessageHTMLViewController+Internal.h"
#import "UAInAppMessageResolution.h"
#import "UAAirshipAutomationCoreImport.h"
#import "UAAutomationResources.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif
/*
 * Hand tuned value that removes excess vertical safe area to make the
 * top padding look more consistent with the iPhone X nub
 */
static CGFloat const ResizingViewExcessiveSafeAreaPadding = -8;

static NSString *const ResizingViewControllerNibName = @"UAInAppMessageResizableViewController";
static CGFloat const ResizingViewControllerDefaultInnerViewPadding = 15;

static CGFloat const DefaultViewToScreenHeightRatio = 0.50;
static CGFloat const DefaultViewToScreenWidthRatio = 0.75;

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

/**
 * The size of the resizing view when default size is overridden.
 */
@property(nonatomic, assign) CGSize size;

/**
 * Flag indicating if the resizing view should lock its aspect ratio when resizing to fit the screen.
 * Only applicable when default size is overridden.
 *
 * Optional. Defaults to `NO` when default size is overridden.
 */
@property(nonatomic, assign) BOOL aspectLock;

@end

/**
 * The in-app message resizing view implementation necessary for rounded corners.
 */
@implementation UAInAppMessageResizableView

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

- (void)layoutSubviews {
    [super layoutSubviews];

    [self applyBorderRounding];
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
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *centerXConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *centerYConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *widthConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *heightConstraint;

/**
 * The completion handler passed in when the message is shown.
 */
@property (nonatomic, copy, nullable) void (^showCompletionHandler)(UAInAppMessageResolution *);

/**
 * The intrinsic size of the resizable view.
 */
@property (nonatomic, assign) CGSize size;

/**
 * The flag that determines if the view will lock the aspect ratio of its intrinsic size
 * when the view needs to resize to fit the screen.
 */
@property (nonatomic, assign) BOOL aspectLock;

/**
 * The flag that determines if the view is overriding the default size.
 */
@property (nonatomic, assign) BOOL overrideSize;

/**
 * The window before the IAA is displayed.
 */
@property (strong, nonatomic, nullable) UIWindow *previousKeyWindow;

@end

@implementation UAInAppMessageResizableViewController

static double const DefaultResizableViewAnimationDuration = 0.2;


+ (instancetype)resizableViewControllerWithChild:(UIViewController *)vc {
    /**
    * The default size is proportional to the size of the screen - and therefore
    * is innately aspect-locking. Initializing with size CGSizeZero will elicit the default size.
    */
    return [[self alloc] initWithViewController:vc];
}

+ (instancetype)resizableViewControllerWithChild:(UIViewController *)vc
                                            size:(CGSize)size
                                      aspectLock:(BOOL)aspectLock {
    return [[self alloc] initWithViewController:vc
                                           size:size
                                     aspectLock:aspectLock];
}

- (instancetype)initWithViewController:(UIViewController *)vc {
    self = [self initFromNib];

    if (self) {
        self.overrideSize = NO;
        self.size = [self defaultScreenRelativeSize];
        self.aspectLock = NO;
        [self addChildViewController:vc];
    }

    return self;
}

- (instancetype)initWithViewController:(UIViewController *)vc
                                  size:(CGSize)size
                            aspectLock:(BOOL)aspectLock  {
    self = [self initFromNib];

    if (self) {
        self.overrideSize = !CGSizeEqualToSize(size, CGSizeZero);
        self.size = size;
        self.aspectLock = aspectLock;
        [self addChildViewController:vc];
    }

    return self;
}

- (void)overrideSizeConstraintsForSize:(CGSize)size {
    CGSize normalizedSize = [self normalizeSize:size];

    // Apply height and width constraints
    self.widthConstraint.active = NO;
    self.widthConstraint = [NSLayoutConstraint constraintWithItem:self.resizingContainerView
                                                        attribute:NSLayoutAttributeWidth
                                                        relatedBy:NSLayoutRelationEqual
                                                           toItem:nil
                                                        attribute:NSLayoutAttributeNotAnAttribute
                                                       multiplier:1
                                                         constant:normalizedSize.width];
    self.widthConstraint.active = YES;

    self.heightConstraint.active = NO;
    self.heightConstraint = [NSLayoutConstraint constraintWithItem:self.resizingContainerView
                                                         attribute:NSLayoutAttributeHeight
                                                         relatedBy:NSLayoutRelationEqual
                                                            toItem:nil
                                                         attribute:NSLayoutAttributeNotAnAttribute
                                                        multiplier:1
                                                          constant:normalizedSize.height];
    self.heightConstraint.active = YES;
}

- (void)addInAppMessageChildViewController:(UIViewController *)child  {
    [self.resizingContainerView addSubview:child.view];
    [UAViewUtils applyContainerConstraintsToContainer:self.resizingContainerView containedView:child.view];
}

-(instancetype)initFromNib {
    return [self initWithNibName:ResizingViewControllerNibName bundle:[UAAutomationResources bundle]];
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

    self.displayFullScreen = false;
    if (self.allowFullScreenDisplay) {
        if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            if (self.extendFullScreenLargeDevice) {
                self.displayFullScreen = true;
            }
        } else {
            self.displayFullScreen = true;
        }
    }

    self.resizingContainerView.allowBorderRounding = !(self.displayFullScreen);

    // will make opaque as part of animation when view appears
    self.view.alpha = 0;
    // disable voiceover interactions with visible items beneath the modal
    self.view.accessibilityViewIsModal = YES;

    if (self.displayFullScreen) {
        // Detect view type
        [self stretchToFullScreen];
        [self refreshViewForCurrentOrientation];
    } else {

        if (self.overrideSize) {
            [self overrideSizeConstraintsForSize:self.size];
        } else if (!self.allowMaxHeight) {
            self.heightConstraint.active = false;
        }

        CGFloat maxWidth = self.maxWidth == nil ? 420.0 : self.maxWidth.floatValue;
        CGFloat maxHeight = self.maxHeight == nil ? 720.0 : self.maxHeight.floatValue;

        // Set max width
        [NSLayoutConstraint constraintWithItem:self.resizingContainerView
                                     attribute:NSLayoutAttributeWidth
                                     relatedBy:NSLayoutRelationLessThanOrEqual
                                        toItem:nil
                                     attribute:NSLayoutAttributeNotAnAttribute
                                    multiplier:1
                                      constant:maxWidth].active = YES;

        // Set max height
        [NSLayoutConstraint constraintWithItem:self.resizingContainerView
                                     attribute:NSLayoutAttributeHeight
                                     relatedBy:NSLayoutRelationLessThanOrEqual
                                        toItem:nil
                                     attribute:NSLayoutAttributeNotAnAttribute
                                    multiplier:1
                                      constant:maxHeight].active = YES;

        [UAInAppMessageUtils applyPaddingToView:self.resizingContainerView
                                        padding:[self padding]
                                        replace:YES];
    }
}

- (UAPadding *)padding {
    return [UAPadding paddingWithTop:@(48.0 + self.additionalPadding.top.floatValue)
                              bottom:@(48.0 + self.additionalPadding.bottom.floatValue)
                             leading:@(24.0 + self.additionalPadding.leading.floatValue)
                            trailing:@(24.0 + self.additionalPadding.trailing.floatValue)];
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

- (void)createWindow {
    // create a new window that covers the entire display
    self.topWindow = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];

    // make sure window appears above any alerts already showing
    self.topWindow.windowLevel = UIWindowLevelAlert;

    // add this view controller to the window
    self.topWindow.rootViewController = self;
}

- (void)displayWindow:(void (^)(UAInAppMessageResolution * _Nonnull))completionHandler {
    self.showCompletionHandler = completionHandler;
    [self.topWindow makeKeyAndVisible];
}

- (void)observeSceneEvents API_AVAILABLE(ios(13.0)) {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sceneRemoved:)
                                                 name:UISceneDidDisconnectNotification
                                               object:nil];
}

- (void)sceneRemoved:(NSNotification *)notification API_AVAILABLE(ios(13.0)) {
    if ([(UIScene *)notification.object isEqual:self.topWindow.windowScene]) {
        [self dismissWithResolution:[UAInAppMessageResolution userDismissedResolution]];
    }
}

- (void)showWithCompletionHandler:(void (^)(UAInAppMessageResolution * _Nonnull))completionHandler {
    if (self.isShowing) {
        UA_LTRACE(@"In-app message resizable view has already been displayed");
        return;
    }

    [self createWindow];
    [self displayWindow:completionHandler];
}

- (void)showWithScene:(UIWindowScene *)scene completionHandler:(void (^)(UAInAppMessageResolution * _Nonnull))completionHandler {
    if (self.isShowing) {
        UA_LTRACE(@"In-app message resizable view has already been displayed");
        return;
    }

    [self createWindow];
    self.topWindow.windowScene = scene;
    [self observeSceneEvents];

    #if TARGET_OS_MACCATALYST
    // In macOS, store the previous window state to prevent it from being removed from the hierarchy
    self.previousKeyWindow = [UAInAppMessageUtils keyWindowFromScene:scene];
    #endif

    [self displayWindow:completionHandler];
}

// Alters contraints to cover the full screen.
- (void)stretchToFullScreen {

    // Deactivate necessary modal constraints
    self.centerXConstraint.active = NO;
    self.centerYConstraint.active = NO;
    self.widthConstraint.active = NO;
    self.heightConstraint.active = NO;

    // Add full screen constraints
    // (note the these are not to the safe area - so insets will need to be provided opn iPhone X)
    [UAViewUtils applyContainerConstraintsToContainer:self.view containedView:self.resizingContainerView];

    // Set shade view to background colorv
    self.shadeView.opaque = YES;
    self.shadeView.alpha = 1;
    self.shadeView.backgroundColor = self.backgroundColor;
}

- (void)tearDown {
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    self.isShowing = NO;
    [self.view removeFromSuperview];
    self.topWindow.windowLevel = UIWindowLevelNormal;
    self.topWindow.hidden = true;
    self.topWindow = nil;

    // In macOS Catalina+, restore the previous window
#if TARGET_OS_MACCATALYST
    // This is necessary else the deallocated/empty alert-level window will still absorb events despite not being the key window
    if (self.previousKeyWindow) {
        [self.previousKeyWindow makeKeyAndVisible];
    }
#endif
}

- (void)dismissWithoutResolution {
    [self tearDown];

    if (self.showCompletionHandler) {
        self.showCompletionHandler(nil);
        self.showCompletionHandler = nil;
    }
}

- (void)dismissWithResolution:(UAInAppMessageResolution *)resolution {
    UA_WEAKIFY(self);
    [UIView animateWithDuration:DefaultResizableViewAnimationDuration animations:^{
        self.view.alpha = 0;

        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        UA_STRONGIFY(self);
        [self tearDown];

        if (self.showCompletionHandler) {
            self.showCompletionHandler(resolution);
            self.showCompletionHandler = nil;
        }
    }];
}

- (void)refreshViewForCurrentOrientation NS_EXTENSION_UNAVAILABLE("Method not available in app extensions") {
    if (self.displayFullScreen) {
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

#pragma mark -
#pragma mark Resizing Helpers

- (CGSize)getMaxSafeSize {
    CGSize screenSize = [UIScreen mainScreen].bounds.size;

    // Get insets for max size
    CGFloat topInset = 0;
    CGFloat bottomInset = 0;
    CGFloat leftInset = 0;
    CGFloat rightInset = 0;

    UIWindow *window = [UAUtils mainWindow];
    topInset = window.safeAreaInsets.top;
    bottomInset = window.safeAreaInsets.bottom;
    leftInset = window.safeAreaInsets.left;
    rightInset = window.safeAreaInsets.right;

    CGFloat maxOverlayWidth = screenSize.width - (fabs(leftInset) + fabs(rightInset));
    CGFloat maxOverlayHeight = screenSize.height - (fabs(topInset) + fabs(bottomInset));

    return CGSizeMake(maxOverlayWidth, maxOverlayHeight);
}

// Helper that generates default screen-relative size - this was previously done in the storyboard
- (CGSize)defaultScreenRelativeSize {
    CGSize maxSafeSize = [self getMaxSafeSize];

    return CGSizeMake(maxSafeSize.width * DefaultViewToScreenWidthRatio,
                      maxSafeSize.height * DefaultViewToScreenHeightRatio);
}

// Normalizes the provided size to aspect fill the current screen
- (CGSize)normalizeSize:(CGSize)size {
    CGFloat requestedAspect = size.width/size.height;

    CGSize maxSafeOverlaySize = [self getMaxSafeSize];
    CGFloat screenAspect = maxSafeOverlaySize.width/maxSafeOverlaySize.height;

    // If aspect ratio is invalid, remove aspect lock
    if (![self validateAspectRatio:requestedAspect]) {
        self.aspectLock = NO;
    }

    BOOL sizeIsValid = ([self validateWidth:size.width] && [self validateHeight:size.height]);

    // If aspect lock is on and size is invalid, adjust size
    if (self.aspectLock && !sizeIsValid) {
        if (screenAspect > requestedAspect) {
            return CGSizeMake(size.width * (maxSafeOverlaySize.height/size.height), maxSafeOverlaySize.height);
        } else {
            return CGSizeMake(maxSafeOverlaySize.width, size.height * (maxSafeOverlaySize.width/size.width));
        }
    }

    // Fill screen width if width is invalid
    if (![self validateWidth:size.width]) {
        size.width = maxSafeOverlaySize.width;
    }

    // Fill screen height if height is invalid
    if (![self validateHeight:size.height]) {
        size.height = maxSafeOverlaySize.height;
    }

    return size;
}

- (BOOL)validateAspectRatio:(CGFloat)aspectRatio {
    if (isnan(aspectRatio) || aspectRatio > INTMAX_MAX) {
        return NO;
    }

    if (aspectRatio == 0) {
        return NO;
    }

    return YES;
}

- (BOOL)validateWidth:(CGFloat)width {
    CGSize screenSize = [self getMaxSafeSize];
    CGFloat maximumOverlayViewWidth = screenSize.width;
    CGFloat minimumOverlayViewWidth = (ResizingViewControllerDefaultInnerViewPadding * 2) * 2;

    if (width < minimumOverlayViewWidth) {
        if (width != 0) {
            UA_LDEBUG(@"Overlay view width is less than the minimum allowed width.");
        }
        return NO;
    }

    if (width > maximumOverlayViewWidth) {
        UA_LDEBUG(@"Overlay view width is greater than the maximum allowed width.");
        return NO;
    }

    return YES;
}

- (BOOL)validateHeight:(CGFloat)height {
    CGSize maxScreenSize = [self getMaxSafeSize];
    CGFloat maximumOverlayViewHeight = maxScreenSize.height;
    CGFloat minimumOverlayViewHeight = (ResizingViewControllerDefaultInnerViewPadding * 2) * 2;

    if (height < minimumOverlayViewHeight) {
        if (height != 0) {
            UA_LDEBUG(@"Overlay view height is less than the minimum allowed height.");
        }
        return NO;
    }

    if (height > maximumOverlayViewHeight) {
        UA_LDEBUG(@"Overlay view height is greater than the maximum allowed height.");
        return NO;
    }

    return YES;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

    // apply the size if size is being overridden
    if (self.overrideSize) {
        [self overrideSizeConstraintsForSize:self.size];
    }

    [self refreshViewForCurrentOrientation];
}


@end
