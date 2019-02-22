/* Copyright Urban Airship and Contributors */

#import "UAOverlayViewController.h"

#import "UABespokeCloseView.h"
#import "UABeveledLoadingIndicator.h"
#import "UAUtils+Internal.h"
#import "UAirship.h"
#import "UAGlobal.h"
#import "UAInboxMessage.h"
#import "UAUser+Internal.h"

#import "UAWKWebViewNativeBridge.h"

#import <QuartzCore/QuartzCore.h>

#define kUAOverlayViewControllerWebViewPadding 15

#define kUAOverlayViewNibName @"UAOverlayView"

static NSMutableSet *overlayControllers_ = nil;

@interface UAOverlayView : UIView

/**
 * The WKWebView used to display the message content.
 */
@property (strong, nonatomic) IBOutlet WKWebView *webView;

@property (strong, nonatomic) IBOutlet UIView *containerView;
@property (strong, nonatomic) IBOutlet UIView *shadeView;
@property (strong, nonatomic) IBOutlet UIButton *closeButton;
@property (strong, nonatomic) IBOutlet UIView *closeButtonView;
@property (strong, nonatomic) IBOutlet UIView *backgroundInsetView;
@property (strong, nonatomic) IBOutlet UABeveledLoadingIndicator *loadingIndicatorView;


/**
 * Block invoked whenever the [UIView layoutSubviews] method is called.
 */
@property(nonatomic, copy) void (^onLayoutSubviews)(void);

@property(nonatomic, assign) CGSize size;
@property(nonatomic, assign) BOOL aspectLock;
@property(nonatomic, assign) UIDeviceOrientation previousOrientation;

@property(nonatomic, strong) NSLayoutConstraint *widthConstraint;
@property(nonatomic, strong) NSLayoutConstraint *heightConstraint;

@end

@implementation UAOverlayView

+ (id)overlayViewWithSize:(CGSize)size aspectLock:(BOOL)aspectLock {
    NSString *nibName = kUAOverlayViewNibName;
    NSBundle *bundle = [UAirship resources];
    
    UAOverlayView *view = [[bundle loadNibNamed:nibName owner:nil options:nil] firstObject];
    [view configureWithSize:size aspectLock:aspectLock];
    
    return view;
}

- (void)configureWithSize:(CGSize)size aspectLock:(BOOL)aspectLock {
    self.size = size;
    self.aspectLock = aspectLock;
}

- (CGSize)getMaxSafeOverlaySize {
    CGSize screenSize = [UIScreen mainScreen].bounds.size;

    // Get insets for max size
    CGFloat topInset = 0;
    CGFloat bottomInset = 0;
    CGFloat leftInset = 0;
    CGFloat rightInset = 0;

    if (@available(iOS 11.0, *)) {
        UIWindow *window = [UAUtils mainWindow];
        topInset = window.safeAreaInsets.top;
        bottomInset = window.safeAreaInsets.bottom;
        leftInset = window.safeAreaInsets.left;
        rightInset = window.safeAreaInsets.right;
    }

    CGFloat maxOverlayWidth = screenSize.width - (fabs(leftInset) + fabs(rightInset));
    CGFloat maxOverlayHeight = screenSize.height - (fabs(topInset) + fabs(bottomInset));

    return CGSizeMake(maxOverlayWidth, maxOverlayHeight);
}

// Normalizes the provided size to aspect fill the current screen
- (CGSize)normalizeSize:(CGSize)size {
    CGFloat requestedAspect = size.width/size.height;

    CGSize maxSafeOverlaySize = [self getMaxSafeOverlaySize];
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

-(BOOL)validateAspectRatio:(CGFloat)aspectRatio {
    if (isnan(aspectRatio) || aspectRatio > INTMAX_MAX) {
        return NO;
    }

    if (aspectRatio == 0) {
        return NO;
    }

    return YES;
}

- (BOOL)validateWidth:(CGFloat)width {
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    CGFloat maximumOverlayViewWidth = screenSize.width;
    CGFloat minimumOverlayViewWidth = (kUAOverlayViewControllerWebViewPadding * 2) * 2;

    if (width < minimumOverlayViewWidth) {
        if (width != 0) {
            UA_LDEBUG(@"Overlay view width is less than the minimum allowed width. Resizing to fit screen.");
        }
        return NO;
    }

    if (width > maximumOverlayViewWidth) {
        UA_LDEBUG(@"Overlay view width is greater than the maximum allowed width. Resizing to fit screen.");
        return NO;
    }

    return YES;
}

- (BOOL)validateHeight:(CGFloat)height {
    CGSize maxScreenSize = [self getMaxSafeOverlaySize];
    CGFloat maximumOverlayViewHeight = maxScreenSize.height;
    CGFloat minimumOverlayViewHeight = (kUAOverlayViewControllerWebViewPadding * 4) * 2;

    if (height < minimumOverlayViewHeight) {
        if (height != 0) {
            UA_LDEBUG(@"Overlay view height is less than the minimum allowed height. Resizing to fit screen.");
        }
        return NO;
    }

    if (height > maximumOverlayViewHeight) {
        UA_LDEBUG(@"Overlay view height is greater than the maximum allowed height. Resizing to fit screen.");
        return NO;
    }

    return YES;
}

- (void)applySizeConstraintsForSize:(CGSize)size {
    // Apply height and width constraints
    self.widthConstraint.active = NO;
    self.widthConstraint = [NSLayoutConstraint constraintWithItem:self.containerView
                                                        attribute:NSLayoutAttributeWidth
                                                        relatedBy:NSLayoutRelationEqual
                                                           toItem:nil
                                                        attribute:NSLayoutAttributeNotAnAttribute
                                                       multiplier:1
                                                         constant:size.width];
    self.widthConstraint.active = YES;

    self.heightConstraint.active = NO;
    self.heightConstraint = [NSLayoutConstraint constraintWithItem:self.containerView
                                                         attribute:NSLayoutAttributeHeight
                                                         relatedBy:NSLayoutRelationEqual
                                                            toItem:nil
                                                         attribute:NSLayoutAttributeNotAnAttribute
                                                        multiplier:1
                                                          constant:size.height];
    self.heightConstraint.active = YES;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    [self.containerView layoutIfNeeded];

    if (self.onLayoutSubviews) {
        self.onLayoutSubviews();
    }

    UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
    if (self.previousOrientation != orientation) {

        // apply the size
        [self applySizeConstraintsForSize:[self normalizeSize:self.size]];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.webView.scrollView setZoomScale:0 animated:YES];
        });

        self.previousOrientation = orientation;
    }
}

@end

@interface UAOverlayViewController() <UAWKWebViewDelegate>


/**
 * The URL being displayed.
 */
@property (nonatomic, strong) NSURL *url;

/**
 * The request headers
 */
@property (nonatomic, strong) NSDictionary *headers;

/**
 * The message being displayed, if applicable. This value may be nil.
 */
@property (nonatomic, strong) UAInboxMessage *message;
@property (nonatomic, strong) UIView *parentView;
@property (nonatomic, strong) UAOverlayView *overlayView;
@property (nonatomic, strong) UIView *background;
@property (nonatomic, strong) UIView *backgroundInset;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UABespokeCloseView *closeButtonView;
@property (nonatomic, strong) UABeveledLoadingIndicator *loadingIndicator;
@property (nonatomic, strong) UAWKWebViewNativeBridge *nativeBridge;
@property (nonatomic, assign) UIUserInterfaceSizeClass lastHorizontalSizeClass;

@end

@implementation UAOverlayViewController

/**
 * Setup a container for the newly allocated controllers, will be released by OS.
 */
+ (void)initialize {
    if (self == [UAOverlayViewController class]) {
        overlayControllers_ = [[NSMutableSet alloc] initWithCapacity:1];
    }
}

+ (void)showOverlayViewController:(UAOverlayViewController *)overlayController {
    // Close existing windows
    [UAOverlayViewController closeAll:NO];
    // Add the overlay controller to our static collection
    [overlayControllers_ addObject:overlayController];
    //load it
    [overlayController load];
}

+ (void)showURL:(NSURL *)url withHeaders:(NSDictionary *)headers {
    CGSize defaultsToFullSize = CGSizeZero;
    UAOverlayViewController *overlayController = [[UAOverlayViewController alloc] initWithParentView:[UAUtils mainWindow]
                                                                                                                      andURL:url
                                                                                                                  andMessage:nil
                                                                                                                  andHeaders:headers
                                                                                                                     size:defaultsToFullSize
                                                                                                               aspectLock:false];
    [self showOverlayViewController:overlayController];
}

+ (void)showURL:(NSURL *)url withHeaders:(NSDictionary *)headers size:(CGSize)size aspectLock:(BOOL)aspectLock {
    UAOverlayViewController *overlayController = [[UAOverlayViewController alloc] initWithParentView:[UAUtils mainWindow]
                                                                                                                      andURL:url
                                                                                                                  andMessage:nil
                                                                                                                  andHeaders:headers
                                                                                                                     size:size
                                                                                                               aspectLock:aspectLock];
    [self showOverlayViewController:overlayController];
}

+ (void)showMessage:(UAInboxMessage *)message {
    [UAOverlayViewController showMessage:message withHeaders:nil];
}

+ (void)showMessage:(UAInboxMessage *)message withHeaders:(NSDictionary *)headers {
    CGSize defaultsToFullSize = CGSizeZero;
    UAOverlayViewController *overlayController = [[UAOverlayViewController alloc] initWithParentView:[UAUtils mainWindow]
                                                                                                                      andURL:message.messageBodyURL
                                                                                                                  andMessage:message
                                                                                                                  andHeaders:headers
                                                                                                                     size:defaultsToFullSize
                                                                                                               aspectLock:false];
    [self showOverlayViewController:overlayController];
}

+ (void)showMessage:(UAInboxMessage *)message withHeaders:(NSDictionary *)headers size:(CGSize)size aspectLock:(BOOL)aspectLock {
    UAOverlayViewController *overlayController = [[UAOverlayViewController alloc] initWithParentView:[UAUtils mainWindow]
                                                                                                                      andURL:message.messageBodyURL
                                                                                                                  andMessage:message
                                                                                                                  andHeaders:headers
                                                                                                                     size:size
                                                                                                               aspectLock:aspectLock];
    [self showOverlayViewController:overlayController];
}

+ (void)closeAll:(BOOL)animated {
    for (UAOverlayViewController *oc in overlayControllers_) {
        [oc closeWindowAnimated:animated];
    }
}

- (instancetype)initWithParentView:(UIView *)parent andURL:(NSURL *)url andMessage:(UAInboxMessage *)message andHeaders:(NSDictionary *)headers size:(CGSize)size aspectLock:(BOOL)aspectLock {
    self = [super init];
    if (self) {
        self.overlayView = [UAOverlayView overlayViewWithSize:size aspectLock:aspectLock];
        self.overlayView.alpha = 0.0;

        self.parentView = parent;
        self.url = url;
        self.message = message;
        self.headers = headers;

        // Set the frame later
        self.overlayView.webView.backgroundColor = [UIColor clearColor];
        self.overlayView.webView.opaque = NO;
        self.nativeBridge = [[UAWKWebViewNativeBridge alloc] init];
        self.nativeBridge.forwardDelegate = self;
        self.overlayView.webView.navigationDelegate = self.nativeBridge;
        [self.overlayView.webView.configuration setDataDetectorTypes:WKDataDetectorTypeNone];
    }

    return self;
}

- (void)dealloc {
    self.overlayView.webView.navigationDelegate = nil;

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIDeviceOrientationDidChangeNotification
                                                  object:nil];
}

- (void)load {
    [self showOverlay];
    [self.overlayView.loadingIndicatorView show];

    UA_WEAKIFY(self)
    void (^loadRequest)(void) = ^{
        UA_STRONGIFY(self)
        NSMutableURLRequest *requestObj = [NSMutableURLRequest requestWithURL:self.url];

        for (id key in self.headers) {
            id value = [self.headers objectForKey:key];
            if (![key isKindOfClass:[NSString class]] || ![value isKindOfClass:[NSString class]]) {
                UA_LWARN(@"Invalid header value.  Only string values are accepted for header names and values.");
                continue;
            }

            [requestObj addValue:value forHTTPHeaderField:key];
        }

        [requestObj setTimeoutInterval:30];

        [self.overlayView.webView stopLoading];
        [self.overlayView.webView loadRequest:requestObj];
    };

    if (self.message) {
        UA_WEAKIFY(self)
        [[UAirship inboxUser] getUserData:^(UAUserData *userData) {
            UA_STRONGIFY(self)
            NSDictionary *auth = @{@"Authorization":[UAUtils userAuthHeaderString:userData]};

            if (!self.headers) {
                self.headers = auth;
            } else {
                NSMutableDictionary *appended = [NSMutableDictionary dictionaryWithDictionary:self.headers];
                [appended addEntriesFromDictionary:auth];
                self.headers = appended;
            }

            loadRequest();

        } dispatcher:[UADispatcher mainDispatcher]];
    } else {
        loadRequest();
    }
}

- (void)showOverlay {
    UIView *parentView = self.parentView;

    if (parentView != nil) {
        [parentView addSubview:self.overlayView];
        self.overlayView.translatesAutoresizingMaskIntoConstraints = NO;

        // Constrain overlay view to center of parent view
        NSLayoutConstraint *xConstraint = [NSLayoutConstraint constraintWithItem:self.overlayView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:parentView attribute:NSLayoutAttributeCenterX multiplier:1 constant:0];
        NSLayoutConstraint *yConstraint = [NSLayoutConstraint constraintWithItem:self.overlayView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:parentView attribute:NSLayoutAttributeCenterY multiplier:1 constant:0];

        // Constrain overlay view to size of parent view
        NSLayoutConstraint *widthConstraint = [NSLayoutConstraint constraintWithItem:self.overlayView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:parentView attribute:NSLayoutAttributeWidth multiplier:1 constant:0];
        NSLayoutConstraint *heightConstraint = [NSLayoutConstraint constraintWithItem:self.overlayView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:parentView attribute:NSLayoutAttributeHeight multiplier:1 constant:0];

        xConstraint.active = YES;
        yConstraint.active = YES;
        widthConstraint.active = YES;
        heightConstraint.active = YES;
    }

    // Technically UABespokeCloseView is a not a UIButton, so we will be adding it as a subView of an actual, transparent one.
    self.closeButtonView.userInteractionEnabled = NO;

    // Tapping the button will finish the overlay and dismiss all views
    [self.overlayView.closeButton addTarget:self action:@selector(finish) forControlEvents:UIControlEventTouchUpInside];

    // Fade in
    [UIView animateWithDuration:0.5 animations:^{
        self.overlayView.alpha = 1.0;
    }];
}

- (void)finish {
    [self finish:YES];
}


/**
 * Removes all views from the hierarchy and releases self, animated if desired.
 * @param animated `YES` to animate the transition, otherwise `NO`
 */
- (void)finish:(BOOL)animated {

    void (^remove)(void) = ^{
        [self.overlayView removeFromSuperview];
        [overlayControllers_ removeObject:self];
    };

    if (animated) {
        // Fade out and remove
        [UIView
         animateWithDuration:0.5
         animations:^{
             self.overlayView.alpha = 0.0;
         } completion:^(BOOL finished){
             remove();
         }];
    } else {
        remove();
    }
}


#pragma mark UAWKWebViewDelegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation {
    [self.overlayView.loadingIndicatorView hide];

    if (self.message) {
        [self.message markMessageReadWithCompletionHandler:nil];
    }
}

- (void)webView:(WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(nonnull NSError *)error {

    UA_WEAKIFY(self);

    // Wait twenty seconds, try again if necessary
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
        UA_STRONGIFY(self)
        if (self) {
            UA_LDEBUG(@"Retrying url: %@", self.url);
            [self load];
        }
    });
}

- (void)closeWindowAnimated:(BOOL)animated {
    UA_LTRACE(@"Closing overlay controller: %@", [self.url absoluteString]);
    [self finish:animated];
}

@end

