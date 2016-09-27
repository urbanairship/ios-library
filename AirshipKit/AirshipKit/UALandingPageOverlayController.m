/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

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

#import "UALandingPageOverlayController.h"

#import "UABespokeCloseView.h"
#import "UABeveledLoadingIndicator.h"
#import "UAUtils.h"
#import "UAGlobal.h"
#import "UAInboxMessage.h"
#import "UIWebView+UAAdditions.h"

#import "UAWebViewDelegate.h"

#import <QuartzCore/QuartzCore.h>

#define kUALandingPageOverlayControllerWebViewPadding 15

static NSMutableSet *overlayControllers_ = nil;

/**
 * A simple UIView subclass to allow hooking into the layoutSubviews method
 */
@interface UALandingPageOverlayView : UIView

/**
 * Block invoked whenever the [UIView layoutSubviews] method is called.
 */
@property(nonatomic, copy) void (^onLayoutSubviews)(void);

@end

@implementation UALandingPageOverlayView

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.onLayoutSubviews) {
        self.onLayoutSubviews();
    }

}

@end

@interface UALandingPageOverlayController()

/**
 * The UIWebView used to display the message content.
 */
@property (nonatomic, strong) UIWebView *webView;

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
@property (nonatomic, strong) UIViewController *parentViewController;
@property (nonatomic, strong) UALandingPageOverlayView *overlayView;
@property (nonatomic, strong) UIView *background;
@property (nonatomic, strong) UIView *backgroundInset;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UABespokeCloseView *closeButtonView;
@property (nonatomic, strong) UABeveledLoadingIndicator *loadingIndicator;
@property (nonatomic, strong) UAWebViewDelegate *webViewDelegate;
@property (nonatomic, assign) UIUserInterfaceSizeClass lastHorizontalSizeClass;

@end

@implementation UALandingPageOverlayController

/** 
 * Setup a container for the newly allocated controllers, will be released by OS.
 */
+ (void)initialize {
    if (self == [UALandingPageOverlayController class]) {
        overlayControllers_ = [[NSMutableSet alloc] initWithCapacity:1];
    }
}

+ (void)showLandingPageController:(UALandingPageOverlayController *)overlayController {
    // Close existing windows
    [UALandingPageOverlayController closeAll:NO];
    // Add the overlay controller to our static collection
    [overlayControllers_ addObject:overlayController];
    //load it
    [overlayController load];
}

+ (void)showURL:(NSURL *)url withHeaders:(NSDictionary *)headers {
    UALandingPageOverlayController *overlayController = [[UALandingPageOverlayController alloc] initWithParentViewController:[UAUtils topController]
                                                                                                                      andURL:url
                                                                                                                  andMessage:nil
                                                                                                                  andHeaders:headers];
    [self showLandingPageController:overlayController];
}

+ (void)showMessage:(UAInboxMessage *)message {
    NSDictionary *headers = @{@"Authorization":[UAUtils userAuthHeaderString]};
    [UALandingPageOverlayController showMessage:message withHeaders:headers];
}

+ (void)showMessage:(UAInboxMessage *)message withHeaders:(NSDictionary *)headers {
    UALandingPageOverlayController *overlayController = [[UALandingPageOverlayController alloc] initWithParentViewController:[UAUtils topController]
                                                                                                                      andURL:message.messageBodyURL
                                                                                                                   andMessage:message
                                                                                                                  andHeaders:headers];
    [self showLandingPageController:overlayController];
}

+ (void)closeAll:(BOOL)animated {
    for (UALandingPageOverlayController *oc in overlayControllers_) {
        [oc closeWebView:oc.webView animated:animated];
    }
}


/**
 * Helper method for determining the display environment. Size classes will be used if
 * available, otherwise the method will fall back on the user interface idiom.
 */
+ (BOOL)isRegularDisplayEnvironment {
    UIWindow *mainWindow = [UAUtils mainWindow];
    if ([mainWindow respondsToSelector:@selector(traitCollection)]) {
        return mainWindow.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular &&
        mainWindow.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassRegular;
    } else {
        return [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad;
    }
}

- (instancetype)initWithParentViewController:(UIViewController *)parent andURL:(NSURL *)url andMessage:(UAInboxMessage *)message andHeaders:(NSDictionary *)headers {
    self = [super init];
    if (self) {

        self.parentViewController = parent;
        self.url = url;
        self.message = message;
        self.headers = headers;

        // Set the frame later
        self.webView = [[UIWebView alloc] initWithFrame:CGRectZero];
        self.webView.backgroundColor = [UIColor clearColor];
        self.webView.opaque = NO;
        self.webViewDelegate = [[UAWebViewDelegate alloc] init];
        self.webViewDelegate.forwardDelegate = self;
        self.webViewDelegate.richContentWindow = self;
        self.webView.delegate = self.webViewDelegate;


        self.webView.dataDetectorTypes = UIDataDetectorTypeNone;

        self.loadingIndicator = [UABeveledLoadingIndicator indicator];

        // Required to receive orientation updates from NSNotificationCenter
        [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(orientationChanged:)
                                                     name:UIDeviceOrientationDidChangeNotification
                                                   object:nil];
        [self buildOverlay];
    }

    return self;
}

- (void)dealloc {
    self.webView.delegate = nil;

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIDeviceOrientationDidChangeNotification
                                                  object:nil];
}

/**
 * Sets the geometry of the landing page depending on the display environment.
 * This method will be called once during initial display, as well as any time
 * the display environment changes prior to dismissal.
 */
- (void)updateLayout {

    UIView *parentView = self.parentViewController.view;

    self.overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.overlayView.autoresizesSubviews = YES;
    self.overlayView.center = CGPointMake(CGRectGetWidth(parentView.bounds)/2.0, CGRectGetHeight(parentView.bounds)/2.0);

    NSUInteger webViewPadding = kUALandingPageOverlayControllerWebViewPadding;

    // Set size for regular width (540 x 620 + webView padding)
    if ([UALandingPageOverlayController isRegularDisplayEnvironment]) {
        self.background.frame = CGRectMake(0.0, 0.0, 540.0 + webViewPadding, 620.0 + webViewPadding);
    } else {
        self.background.frame = CGRectInset(self.overlayView.frame, 0, webViewPadding);
    }

    // Center the background in the middle of the overlay
    self.background.center = CGPointMake(CGRectGetWidth(self.overlayView.frame)/2.0, CGRectGetHeight(self.overlayView.frame)/2.0);

    if ([UALandingPageOverlayController isRegularDisplayEnvironment]) {
        self.background.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
        UIViewAutoresizingFlexibleTopMargin |
        UIViewAutoresizingFlexibleRightMargin |
        UIViewAutoresizingFlexibleBottomMargin;
    } else {
        self.background.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }

    self.backgroundInset.frame = CGRectInset(CGRectMake(0,0,CGRectGetWidth(self.background.frame),CGRectGetHeight(self.background.frame)), webViewPadding, webViewPadding);

    // Set the webView's frame to be identical to the background inset
    self.webView.frame = CGRectMake(webViewPadding, webViewPadding, CGRectGetWidth(self.backgroundInset.frame), CGRectGetHeight(self.backgroundInset.frame));

    if ([UALandingPageOverlayController isRegularDisplayEnvironment]) {
        self.webView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
        UIViewAutoresizingFlexibleTopMargin |
        UIViewAutoresizingFlexibleRightMargin |
        UIViewAutoresizingFlexibleBottomMargin;
    } else {
        self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }

    self.loadingIndicator.center = CGPointMake(CGRectGetWidth(self.webView.frame)/2.0, CGRectGetHeight(self.webView.frame)/2.0);

    if ([UALandingPageOverlayController isRegularDisplayEnvironment]) {
        self.closeButton.autoresizingMask = UIViewAutoresizingNone;
    } else {
        self.closeButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
    }

    [self.closeButton setFrame:CGRectMake(
                                     CGRectGetWidth(self.background.frame) - CGRectGetWidth(self.closeButtonView.frame),
                                     0,
                                     CGRectGetWidth(self.closeButtonView.frame),
                                     CGRectGetHeight(self.closeButtonView.frame))];
}

- (void)buildOverlay {

    UIView *parentView = self.parentViewController.view;

    // Note that we're using parentView.bounds instead of frame here, so that we'll have the correct dimensions if the
    // Parent view is autorotated or otherwised transformed.

    self.overlayView = [[UALandingPageOverlayView alloc] initWithFrame:
                        CGRectMake(0, 0, CGRectGetWidth(parentView.bounds), CGRectGetHeight(parentView.bounds))];
    self.overlayView.alpha = 0.0;
    self.overlayView.backgroundColor = [UIColor clearColor];

    // Update the layout whenever the bounds change, if needed
    __weak UALandingPageOverlayController *weakSelf = self;
    self.overlayView.onLayoutSubviews = ^{
        UALandingPageOverlayController *strongSelf = weakSelf;
        // If we're running on iOS 8 or above
        if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){8, 0, 0}]) {
            // Get the current horizontal size class
            UIUserInterfaceSizeClass horizontalSizeClass = [UAUtils mainWindow].traitCollection.horizontalSizeClass;
            // If the there has been a change, update layout constraints
            if (horizontalSizeClass != self.lastHorizontalSizeClass) {
                strongSelf.lastHorizontalSizeClass = horizontalSizeClass;
                [strongSelf updateLayout];
            }
        }
    };

    if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){8, 0, 0}]) {
        self.lastHorizontalSizeClass = [UAUtils mainWindow].traitCollection.horizontalSizeClass;
    }
    // Padding for the the webview
    NSInteger webViewPadding = kUALandingPageOverlayControllerWebViewPadding;

    // Add the window background
    self.background = [[UIView alloc] initWithFrame:CGRectInset(self.overlayView.frame, 0, webViewPadding)];

    // Make the background transparent, so that the close button can safely overlap the corner of the webView
    self.background.backgroundColor = [UIColor clearColor];

    [self.overlayView addSubview:self.background];

    // Create and add a background inset that will serve as the visible background to the webview
    self.backgroundInset = [[UIView alloc] initWithFrame:
                               CGRectInset(CGRectMake(0,0,CGRectGetWidth(self.background.frame),CGRectGetHeight(self.background.frame)),
                                           webViewPadding, webViewPadding)];
    self.backgroundInset.backgroundColor = [UIColor whiteColor];
    self.backgroundInset.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    [self.background addSubview:self.backgroundInset];
    [self.background addSubview:self.webView];

    // Add the loading indicator and center it in the middle of the webView
    [self.webView addSubview:self.loadingIndicator];

    // Add the close button
    self.closeButtonView = [[UABespokeCloseView alloc] initWithFrame:CGRectMake(0.0, 0.0, 35.0, 35.0)];

    // Technically UABespokeCloseView is a not a UIButton, so we will be adding it as a subView of an actual, transparent one.
    self.closeButtonView.userInteractionEnabled = NO;

    self.closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.closeButton addSubview:self.closeButtonView];

    // Tapping the button will finish the overlay and dismiss all views
    [self.closeButton addTarget:self action:@selector(finish) forControlEvents:UIControlEventTouchUpInside];

    [self.background addSubview:self.closeButton];

    // Update the layout for the current display context
    [self updateLayout];

    [self.overlayView layoutSubviews];
}

- (void)load {

    NSMutableURLRequest *requestObj = [NSMutableURLRequest requestWithURL:self.url];

    for (id key in self.headers) {
        id value = [self.headers objectForKey:key];
        if (![key isKindOfClass:[NSString class]] || ![value isKindOfClass:[NSString class]]) {
            UA_LERR(@"Invalid header value.  Only string values are accepted for header names and values.");
            continue;
        }

        [requestObj addValue:value forHTTPHeaderField:key];
    }

    [requestObj setTimeoutInterval:30];

    [self.webView stopLoading];
    [self.webView loadRequest:requestObj];
    [self showOverlay];

    [self.loadingIndicator show];
}

- (void)showOverlay {

    [self.parentViewController.view addSubview:self.overlayView];

    // Dims the contents behind the popup window
    UIView *shadeView = [[UIView alloc] initWithFrame:self.overlayView.bounds];
    shadeView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    shadeView.backgroundColor = [UIColor blackColor];
    shadeView.alpha = 0.3;
    shadeView.userInteractionEnabled = NO;

    [self.overlayView addSubview:shadeView];

    // Send to the back so it doesn't obscure the landing page/etc
    [self.overlayView sendSubviewToBack:shadeView];

    // Fade in
    [UIView animateWithDuration:0.5 animations:^{
        self.overlayView.alpha = 1.0;
    }];
}

- (void)orientationChanged:(NSNotification *)notification {
    // Note that face up and face down orientations will be ignored as this
    // casts a device orientation to an interface orientation
    
    if (([self.parentViewController supportedInterfaceOrientations] &
         (UIInterfaceOrientation)[UIDevice currentDevice].orientation) == 0) {
        return;
    }

    // This will inject the current device orientation
    [self.webView injectInterfaceOrientation:(UIInterfaceOrientation)[[UIDevice currentDevice] orientation]];
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


#pragma mark UIWebViewDelegate

- (void)webViewDidFinishLoad:(UIWebView *)wv {
    [self.loadingIndicator hide];

    if (self.message) {
        [self.message markMessageReadWithCompletionHandler:nil];
    }

    [self.webView injectInterfaceOrientation:(UIInterfaceOrientation)[[UIDevice currentDevice] orientation]];
}

- (void)webView:(UIWebView *)wv didFailLoadWithError:(NSError *)error {

    __typeof(self) __weak weakSelf = self;

    // Wait twenty seconds, try again if necessary
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
        __typeof(self) __strong strongSelf = weakSelf;
        if (strongSelf) {
            UA_LINFO(@"Retrying landing page url: %@", strongSelf.url);
            [strongSelf load];
        }
    });

}

#pragma mark UARichContentWindow

- (void)closeWebView:(UIWebView *)webView animated:(BOOL)animated {
    UA_LDEBUG(@"Closing landing page overlay controller: %@", [self.url absoluteString]);
    [self finish:animated];
}

@end

