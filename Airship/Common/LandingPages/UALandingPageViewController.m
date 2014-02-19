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

/* UAInboxOverlayController is based on MTPopupWindow
 * http://www.touch-code-magazine.com/showing-a-popup-window-in-ios-class-for-download/
 *
 * Copyright 2011 Marin Todorov. MIT license
 * http://www.opensource.org/licenses/mit-license.php
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software
 * and associated documentation files (the "Software"), to deal in the Software without restriction,
 * including without limitation the rights to use, copy, modify, merge, publish, distribute,
 * sublicense, and/or sell copies of the Software, and to permit persons to whom the Software
 * is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all copies or
 * substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
 * BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
 * DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "UALandingPageViewController.h"

#import "UAInboxMessage.h"
#import "UAInboxMessageList.h"
#import "UAInbox.h"
#import "UAInboxUI.h"
#import "UAUtils.h"

#import "UABespokeCloseView.h"

#import "UIWebView+UAAdditions.h"
#import "UAWebViewTools.h"

#import <QuartzCore/QuartzCore.h>

#define kShadeViewTag 1000

static NSMutableSet *overlayControllers = nil;

@interface UALandingPageViewController()

- (void)loadURL:(NSURL *)url;

@property(nonatomic, strong) UIViewController *landingPageHostController;
@property(nonatomic, strong) UABeveledLoadingIndicator *loadingIndicator;
@end

@implementation UALandingPageViewController

// While this breaks from convention, it does not actually leak. Turning off analyzer warnings
+ (void)showURL:(NSURL *)url {

    [UALandingPageViewController closeWindow:NO];

    UIViewController *topController = [UALandingPageViewController topController];

    UALandingPageViewController *overlayController = [[UALandingPageViewController alloc] initWithParentViewController:topController andURL:url];

    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:overlayController];
    navController.modalPresentationStyle = UIModalPresentationFormSheet;
    [topController presentViewController:navController animated:YES completion:NULL];

    [overlayController loadURL:url];
}


// a utility method that grabs the top-most view controller
+ (UIViewController *)topController {
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;

    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }

    return topController;
}

+ (void)closeWindow:(BOOL)animated {

    // It's the top view controller with a child root view controller
    UIViewController *topController = [UALandingPageViewController topController];
    UALandingPageViewController *possibleLandingPageController = [[topController childViewControllers] firstObject];
    if ([possibleLandingPageController isKindOfClass:[UALandingPageViewController class]]) {
        UA_LDEBUG(@"Dismissing landing page.");
        [possibleLandingPageController.presentingViewController dismissViewControllerAnimated:animated completion:NULL];
    }
}

- (id)initWithParentViewController:(UIViewController *)parent andURL:(NSURL *)url {
    self = [super init];
    if (self) {
        // Initialization code here.

        self.landingPageHostController = parent;

        //set the frame later
        self.webView = [[UIWebView alloc] initWithFrame:parent.view.frame];
        self.webView.opaque = YES;
        self.webView.delegate = self;
        self.webView.scalesPageToFit = YES;
        self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

        self.webView.dataDetectorTypes = UIDataDetectorTypeAll;

        self.view = self.webView;

        self.loadingIndicator = [UABeveledLoadingIndicator indicator];

        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop
                                                                                              target:self
                                                                                              action:@selector(finish)];

        //required to receive orientation updates from NSNotificationCenter
        [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(orientationChanged:)
                                                     name:UIDeviceOrientationDidChangeNotification object:nil];
    }

    return self;
}

- (void)dealloc {
    self.webView.delegate = nil;

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIDeviceOrientationDidChangeNotification
                                                  object:nil];
}

- (void)loadURL:(NSURL *)url {


    [self.webView addSubview:self.loadingIndicator];
    self.loadingIndicator.center = self.parentViewController.view.center;

    [self.loadingIndicator show];

    //TODO: consider adding a hard-coded HTML frame
    NSMutableURLRequest *requestObj = [NSMutableURLRequest requestWithURL:url];

    [requestObj setTimeoutInterval:30];

    [self.webView stopLoading];
    [self.webView loadRequest:requestObj];
}

- (BOOL)shouldTransition {
    return [UIView respondsToSelector:@selector(transitionFromView:toView:duration:options:completion:)];
}


- (void)orientationChanged:(NSNotification *)notification {
    // Note that face up and face down orientations will be ignored as this
    // casts a device orientation to an interface orientation

// IF iOS6+, the following will work:
//
//    if ((self.parentViewController.supportedInterfaceOrientations & (UIInterfaceOrientation)[UIDevice currentDevice].orientation) == 0) {
//        return;
//    }
// Otherwise:

    if (![self.parentViewController shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)[UIDevice currentDevice].orientation]) {
        return;
    }

    // This will inject the current device orientation
    [self.webView willRotateToInterfaceOrientation:(UIInterfaceOrientation)[[UIDevice currentDevice] orientation]];
}

/**
 * Removes all views from the hierarchy and releases self
 */
- (void)finish {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark -
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

    UALOG(@"Failed to load message: %@", error);
}


@end
