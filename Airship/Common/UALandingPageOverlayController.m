/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

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

#import "UIWebView+UAAdditions.h"
#import "UAWebViewTools.h"

#import <QuartzCore/QuartzCore.h>

static NSMutableSet *overlayControllers = nil;

@interface UALandingPageOverlayController()

/**
 * The UIWebView used to display the message content.
 */
@property(nonatomic, strong) UIWebView *webView;

/**
 * The URL being displayed.
 */
@property(nonatomic, strong) NSURL *url;
@property(nonatomic, strong) UIViewController *parentViewController;
@property(nonatomic, strong) UIView *overlayView;
@property(nonatomic, strong) UABeveledLoadingIndicator *loadingIndicator;

@end

@implementation UALandingPageOverlayController

/** 
 * Setup a container for the newly allocated controllers, will be released by OS.
 */
+ (void)initialize {
    if (self == [UALandingPageOverlayController class]) {
        overlayControllers = [[NSMutableSet alloc] initWithCapacity:1];
    }
}

+ (void)showURL:(NSURL *)url {

    // Close existing windows
    [UALandingPageOverlayController closeWindow:NO];

    // Get the top view controller
    UIViewController *topController = [UALandingPageOverlayController topController];

    UALandingPageOverlayController *overlayController = [[UALandingPageOverlayController alloc] initWithParentViewController:topController andURL:url];
    [overlayControllers addObject:overlayController];

    [overlayController loadURL:url];
}

+ (void)closeWindow:(BOOL)animated {
    for (UALandingPageOverlayController *oc in overlayControllers) {
        UA_LDEBUG(@"Closing landing page overlay controller: %@", [oc.url absoluteString]);
        [oc finish:animated];
    }
}

/** 
 * A utility method that grabs the top-most view controller
 */
+ (UIViewController *)topController {
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;

    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }

    return topController;
}

- (id)initWithParentViewController:(UIViewController *)parent andURL:(NSURL *)url {
    self = [super init];
    if (self) {

        self.parentViewController = parent;

        // Set the frame later
        self.webView = [[UIWebView alloc] initWithFrame:CGRectZero];
        self.webView.backgroundColor = [UIColor clearColor];
        self.webView.opaque = NO;
        self.webView.delegate = self;
        self.webView.dataDetectorTypes = UIDataDetectorTypeNone;
        self.webView.scalesPageToFit = YES;

        // Hack to hide the ugly webview gradient (iOS6 and earlier)
        for (UIView *subView in [self.webView subviews]) {
            if ([subView isKindOfClass:[UIScrollView class]]) {
                for (UIView *shadowView in [subView subviews]) {
                    if ([shadowView isKindOfClass:[UIImageView class]]) {
                        [shadowView setHidden:YES];
                    }
                }
            }
        }

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

- (void)buildOverlay {

    UIView *parentView = self.parentViewController.view;

    // Note that we're using parentView.bounds instead of frame here, so that we'll have the correct dimensions if the
    // Parent view is autorotated or otherwised transformed.

    self.overlayView = [[UIView alloc] initWithFrame:
                        CGRectMake(0, 0, CGRectGetWidth(parentView.bounds), CGRectGetHeight(parentView.bounds))];

    self.overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.overlayView.autoresizesSubviews = YES;
    self.overlayView.center = CGPointMake(CGRectGetWidth(parentView.bounds)/2.0, CGRectGetHeight(parentView.bounds)/2.0);
    self.overlayView.alpha = 0.0;
    self.overlayView.backgroundColor = [UIColor clearColor];

    // Padding for the the webview
    NSInteger webViewPadding = 15;

    // Add the window background
    UIView *background = [[UIView alloc] initWithFrame:CGRectInset(self.overlayView.frame, 0, webViewPadding)];

    // Set size for iPad (540 x 620 + webView padding)
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        background.frame = CGRectMake(0.0, 0.0, 540.0 + webViewPadding, 620.0 + webViewPadding);
    }

    // Center the background in the middle of the overlay
    background.center = CGPointMake(CGRectGetWidth(self.overlayView.frame)/2.0, CGRectGetHeight(self.overlayView.frame)/2.0);

    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        background.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
        UIViewAutoresizingFlexibleTopMargin |
        UIViewAutoresizingFlexibleRightMargin |
        UIViewAutoresizingFlexibleBottomMargin;
    } else {
        background.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }

    // Make the background transparent, so that the close button can safely overlap the corner of the webView
    background.backgroundColor = [UIColor clearColor];

    [self.overlayView addSubview:background];

    // Create and add a background inset that will serve as the visible background to the webview
    UIView *backgroundInset = [[UIView alloc] initWithFrame:
                               CGRectInset(CGRectMake(0,0,CGRectGetWidth(background.frame),CGRectGetHeight(background.frame)),
                                           webViewPadding, webViewPadding)];
    backgroundInset.backgroundColor = [UIColor whiteColor];
    backgroundInset.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    [background addSubview:backgroundInset];

    // Set the webView's frame to be identical to the background inset
    self.webView.frame = CGRectMake(webViewPadding, webViewPadding, CGRectGetWidth(backgroundInset.frame), CGRectGetHeight(backgroundInset.frame));

    self.webView.scalesPageToFit = YES;

    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        self.webView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
        UIViewAutoresizingFlexibleTopMargin |
        UIViewAutoresizingFlexibleRightMargin |
        UIViewAutoresizingFlexibleBottomMargin;
    } else {
        self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }

    [background addSubview:self.webView];

    // Add the loading indicator and center it in the middle of the webView
    [self.webView addSubview:self.loadingIndicator];
    self.loadingIndicator.center = CGPointMake(CGRectGetWidth(self.webView.frame)/2.0, CGRectGetHeight(self.webView.frame)/2.0);

    if (self.webView.isLoading) {
        [self.loadingIndicator show];
    }

    // Add the close button
    UABespokeCloseView *closeButtonView = [[UABespokeCloseView alloc] initWithFrame:CGRectMake(0.0, 0.0, 35.0, 35.0)];

    // Technically UABespokeCloseView is a not a UIButton, so we will be adding it as a subView of an actual, transparent one.
    closeButtonView.userInteractionEnabled = NO;

    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        closeButton.autoresizingMask = UIViewAutoresizingNone;
    } else {
        closeButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
    }

    [closeButton setFrame:CGRectMake(
                                     CGRectGetWidth(background.frame) - CGRectGetWidth(closeButtonView.frame),
                                     0,
                                     CGRectGetWidth(closeButtonView.frame),
                                     CGRectGetHeight(closeButtonView.frame))];

    [closeButton addSubview:closeButtonView];

    // Tapping the button will finish the overlay and dismiss all views
    [closeButton addTarget:self action:@selector(finish) forControlEvents:UIControlEventTouchUpInside];

    [background addSubview:closeButton];

    [self.overlayView layoutSubviews];
}

- (void)loadURL:(NSURL *)url {

    self.url = url;

    NSMutableURLRequest *requestObj = [NSMutableURLRequest requestWithURL:url];

    // TODO: add an auth enum to the overlay, so it can be set by the caller?
    [requestObj setTimeoutInterval:30];

    [self.webView stopLoading];
    [self.webView loadRequest:requestObj];
    [self showOverlay];
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

    if (![self.parentViewController shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)[UIDevice currentDevice].orientation]) {
        return;
    }

    // This will inject the current device orientation
    [self.webView willRotateToInterfaceOrientation:(UIInterfaceOrientation)[[UIDevice currentDevice] orientation]];
}

- (void)finish {
    [self finish:YES];
}

/**
 * Removes all views from the hierarchy and releases self, animated if desired.
 */
- (void)finish:(BOOL)animated {

    void (^remove)(void) = ^{
        [self.overlayView removeFromSuperview];
        [overlayControllers removeObject:self];
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

- (BOOL)webView:(UIWebView *)wv shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    return [UAWebViewTools webView:wv shouldStartLoadWithRequest:request navigationType:navigationType];
}

- (void)webViewDidStartLoad:(UIWebView *)wv {
    [self.webView willRotateToInterfaceOrientation:(UIInterfaceOrientation)[[UIDevice currentDevice] orientation]];
}

- (void)webViewDidFinishLoad:(UIWebView *)wv {
    [self.loadingIndicator hide];

    [self.webView injectViewportFix];
}

- (void)webView:(UIWebView *)wv didFailLoadWithError:(NSError *)error {

    [self.loadingIndicator hide];

    if (error.code == NSURLErrorCancelled) {
        return;
    }

    UALOG(@"Failed to load message: %@", [error localizedDescription]);
}

@end

