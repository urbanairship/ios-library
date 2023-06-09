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

static NSString *const ResizingViewControllerNibName = @"UAInAppMessageResizableViewController";

static float ResizingViewControllerMaxWidth = 420.0;
static float ResizingViewControllerMaxHeight = 720.0;


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
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *widthConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *heightConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *trailingConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *leadingConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *topConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *bottomConstraint;


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
        self.size = CGSizeZero;
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
        self.size = size;
        self.aspectLock = aspectLock;
        [self addChildViewController:vc];
    }

    return self;
}

- (void)addInAppMessageChildViewController:(UIViewController *)child  {
    [self.resizingContainerView addSubview:child.view];
    [UAViewUtils applyContainerConstraintsToContainer:self.resizingContainerView
                                        containedView:child.view];
}

-(instancetype)initFromNib {
    return [self initWithNibName:ResizingViewControllerNibName bundle:[UAAutomationResources bundle]];
}

- (BOOL)isFullScreen {
    if (self.allowFullScreenDisplay) {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            return self.extendFullScreenLargeDevice;
        } else {
            return YES;
        }
    }    
    return NO;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    if (self.childViewControllers.count > 0) {
        UIViewController *child = self.childViewControllers[0];
        [self addInAppMessageChildViewController:child];
        [child didMoveToParentViewController:self];
    }

    self.view.alpha = 0;
    self.view.accessibilityViewIsModal = YES;
    self.resizingContainerView.backgroundColor = self.backgroundColor;

    if ([self isFullScreen]) {
        self.resizingContainerView.allowBorderRounding = NO;
        self.shadeView.opaque = YES;
        self.shadeView.alpha = 1;
        self.shadeView.backgroundColor = self.backgroundColor;
    } else {
        if (self.borderRadius > 0) {
            self.resizingContainerView.allowBorderRounding = YES;
            self.resizingContainerView.borderRadius = self.borderRadius;
        }

        if (self.size.width > 0) {
            self.widthConstraint.active = NO;
            NSLayoutConstraint *constraint = [NSLayoutConstraint constraintWithItem:self.resizingContainerView
                                                                          attribute:NSLayoutAttributeWidth
                                                                          relatedBy:NSLayoutRelationEqual
                                                                             toItem:nil
                                                                          attribute:NSLayoutAttributeNotAnAttribute
                                                                         multiplier:1
                                                                           constant:self.size.width];

            constraint.priority = 999;
            constraint.active = YES;
        } else {
            CGFloat maxWidth = self.maxWidth == nil ? ResizingViewControllerMaxWidth : self.maxWidth.floatValue;
            if (!self.aspectLock && self.aspectRatio) {
                [NSLayoutConstraint constraintWithItem:self.resizingContainerView
                                             attribute:NSLayoutAttributeWidth
                                             relatedBy:NSLayoutRelationEqual
                                                toItem:self.resizingContainerView
                                             attribute:NSLayoutAttributeHeight
                                            multiplier:[self.aspectRatio doubleValue]
                                              constant:0.0f].active = YES;
            }
            [NSLayoutConstraint constraintWithItem:self.resizingContainerView
                                             attribute:NSLayoutAttributeWidth
                                             relatedBy:NSLayoutRelationLessThanOrEqual
                                                toItem:nil
                                             attribute:NSLayoutAttributeNotAnAttribute
                                            multiplier:1
                                              constant:maxWidth].active = YES;
            
        }


        if (self.size.height > 0) {
            if (!self.aspectRatio) {
                self.heightConstraint.active = NO;
                NSLayoutConstraint *constraint = [NSLayoutConstraint constraintWithItem:self.resizingContainerView
                                                                              attribute:NSLayoutAttributeHeight
                                                                              relatedBy:NSLayoutRelationEqual
                                                                                 toItem:nil
                                                                              attribute:NSLayoutAttributeNotAnAttribute
                                                                             multiplier:1
                                                                               constant:self.size.height];
                
                constraint.priority = 999;
                constraint.active = YES;
            }
        } else {
            CGFloat maxHeight = self.maxHeight == nil ? ResizingViewControllerMaxHeight : self.maxHeight.floatValue;

            // Set max height
            [NSLayoutConstraint constraintWithItem:self.resizingContainerView
                                         attribute:NSLayoutAttributeHeight
                                         relatedBy:NSLayoutRelationLessThanOrEqual
                                            toItem:nil
                                         attribute:NSLayoutAttributeNotAnAttribute
                                        multiplier:1
                                          constant:maxHeight].active = YES;

        }

        if (!self.allowMaxHeight) {
            self.heightConstraint.active = NO;
        }

        if (self.size.height > 0 && self.size.width > 0 && self.aspectLock) {
            CGFloat aspectRatio = self.size.width/self.size.height;
            [NSLayoutConstraint constraintWithItem:self.resizingContainerView
                                         attribute:NSLayoutAttributeWidth
                                         relatedBy:NSLayoutRelationEqual
                                            toItem:self.resizingContainerView
                                         attribute:NSLayoutAttributeHeight
                                        multiplier:aspectRatio
                                          constant:0.0f].active = YES;
        }

        self.bottomConstraint.constant = (48.0 + self.additionalPadding.trailing.floatValue);

        self.topConstraint.constant = -(48 + self.additionalPadding.trailing.floatValue);

        self.leadingConstraint.constant = (24.0 + self.additionalPadding.trailing.floatValue);


        self.trailingConstraint.constant = -(24.0 + self.additionalPadding.trailing.floatValue);
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
        }];
    }
}

#pragma mark -
#pragma mark Core Functionality

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

    self.topWindow = [UAUtils createWindowWithRootViewController:self];
    [self displayWindow:completionHandler];
}

- (void)showWithScene:(UIWindowScene *)scene completionHandler:(void (^)(UAInAppMessageResolution * _Nonnull))completionHandler {
    if (self.isShowing) {
        UA_LTRACE(@"In-app message resizable view has already been displayed");
        return;
    }

    self.topWindow = [UAUtils createWindowWithScene:scene
                                 rootViewController:self];
    [self observeSceneEvents];

    #if TARGET_OS_MACCATALYST
    // In macOS, store the previous window state to prevent it from being removed from the hierarchy
    self.previousKeyWindow = [UAInAppMessageUtils keyWindowFromScene:scene];
    #endif

    [self displayWindow:completionHandler];
}

- (void)tearDown {
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    self.isShowing = NO;
    [self.view removeFromSuperview];
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
@end
