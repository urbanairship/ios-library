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

#import "UAKablamOverlayController.h"

#import "UABespokeCloseView.h"
#import "UABeveledLoadingIndicator.h"
#import "UAUtils.h"
#import "UAGlobal.h"

#import "UIWebView+UAAdditions.h"
#import "UAWebViewTools.h"

#import <QuartzCore/QuartzCore.h>

#define kShadeViewTag (NSInteger)1000

static NSMutableSet *overlayControllers = nil;

@interface UAKablamOverlayController()


- (void)closePopupWindow;
- (void)loadURL:(NSURL *)url;
- (void)displayWindow;
- (void)constructWindow;
- (void)finish;
- (void)orientationChanged:(NSNotification *)notification;
- (void)removeChildViews;

+ (UIViewController *)topController;

/**
 * The UIWebView used to display the message content.
 */
@property(nonatomic, strong) UIWebView *webView;

/**
 * The URL being displayed.
 */
@property(nonatomic, strong) NSURL *url;

@property(nonatomic, strong) UIViewController *parentViewController;
@property(nonatomic, strong) UIView *bgView;
@property(nonatomic, strong) UIView *bigPanelView;
@property(nonatomic, strong) UABeveledLoadingIndicator *loadingIndicator;
@end

@implementation UAKablamOverlayController

// Setup a container for the newly allocated controllers, will be released by OS. 
+ (void)initialize {
    if (self == [UAKablamOverlayController class]) {
        overlayControllers = [[NSMutableSet alloc] initWithCapacity:1];
    }
}

+ (void)showURL:(NSURL *)url {

    //close existing windows
    [UAKablamOverlayController closeWindow];

    // get the top view controller
    UIViewController *topController = [UAKablamOverlayController topController];

    UAKablamOverlayController *overlayController = [[UAKablamOverlayController alloc] initWithParentViewController:topController andURL:url];
    [overlayControllers addObject:overlayController];

    [overlayController loadURL:url];
}

+ (void)closeWindow {
    for (UAKablamOverlayController *oc in overlayControllers) {
        [oc closePopupWindow];
    }
}

// a utility method that grabs the top-most view controller
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
        // Initialization code here.
        
        self.parentViewController = parent;
        UIView *sview = parent.view;
        
        self.bgView = [[UIView alloc] initWithFrame:sview.bounds];
        self.bgView.autoresizesSubviews = YES;
        self.bgView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        [sview addSubview:self.bgView];
        
        //set the frame later
        self.webView = [[UIWebView alloc] initWithFrame:CGRectZero];
        self.webView.backgroundColor = [UIColor clearColor];
        self.webView.opaque = NO;
        self.webView.delegate = self;
        self.webView.dataDetectorTypes = UIDataDetectorTypeNone;
        self.webView.scalesPageToFit = YES;
        
        //hack to hide the ugly webview gradient
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
                
        //required to receive orientation updates from NSNotificationCenter
        [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(orientationChanged:) 
                                                     name:UIDeviceOrientationDidChangeNotification
                                                   object:nil];
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

    NSMutableURLRequest *requestObj = [NSMutableURLRequest requestWithURL:url];

    // No auth required here:
    // TODO: add an auth enum to the overlay, so it can be set by the caller?
    [requestObj setTimeoutInterval:30];
    
    [self.webView stopLoading];
    [self.webView loadRequest:requestObj];
    [self performSelector:@selector(displayWindow) withObject:nil afterDelay:0.1];
}

- (void)constructWindow {
    
    //the new panel
    self.bigPanelView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.bgView.frame.size.width, self.bgView.frame.size.height)];
    
    self.bigPanelView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.bigPanelView.autoresizesSubviews = YES;
    self.bigPanelView.center = CGPointMake(self.bgView.frame.size.width/2.0, self.bgView.frame.size.height/2.0);

    //on iPad 540.0 x 620.0

    //add the window background
    UIView *background = [[UIView alloc] initWithFrame:CGRectInset(self.bigPanelView.frame, 15.0, 30.0)];

    // set size for iPad
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        background.frame = CGRectMake(0.0, 0.0, 540.0, 620.0);
    }

    background.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    background.backgroundColor = [UIColor whiteColor];

    background.layer.borderColor = [[UIColor blackColor] CGColor];
    background.layer.borderWidth = 0.5;
    background.center = CGPointMake(self.bigPanelView.frame.size.width/2.0, self.bigPanelView.frame.size.height/2.0);
    [self.bigPanelView addSubview:background];

    //add the web view
    NSInteger webOffset = 0;
    self.webView.frame = CGRectInset(background.frame, webOffset, webOffset);
    self.webView.scalesPageToFit = YES;

    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    [self.bigPanelView addSubview:self.webView];
    
    [self.webView addSubview:self.loadingIndicator];
    self.loadingIndicator.center = CGPointMake(self.webView.frame.size.width/2.0, self.webView.frame.size.height/2.0);

    if (self.webView.isLoading) {
        [self.loadingIndicator show];
    }
    
    //add the close button
    UABespokeCloseView *bespokeCloseButtonView = [[UABespokeCloseView alloc] initWithFrame:CGRectMake(0.0, 0.0, 35.0, 35.0)];
    bespokeCloseButtonView.userInteractionEnabled = NO;

    NSUInteger closeBtnOffset = 0;
    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    closeButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;

    [closeButton setFrame:CGRectMake(
                                  background.frame.size.width - bespokeCloseButtonView.frame.size.width - closeBtnOffset,
                                  closeBtnOffset,
                                  bespokeCloseButtonView.frame.size.width + closeBtnOffset,
                                  bespokeCloseButtonView.frame.size.height + closeBtnOffset)];

    [closeButton addSubview:bespokeCloseButtonView];
    [closeButton addTarget:self action:@selector(closePopupWindow) forControlEvents:UIControlEventTouchUpInside];

    [self.webView addSubview:closeButton];

    // custom resize mask for iPad. TODO: see if this is also what we want on the iPhone.
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        self.webView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                                        UIViewAutoresizingFlexibleTopMargin |
                                        UIViewAutoresizingFlexibleRightMargin |
                                        UIViewAutoresizingFlexibleBottomMargin;

        background.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                                      UIViewAutoresizingFlexibleTopMargin |
                                      UIViewAutoresizingFlexibleRightMargin |
                                      UIViewAutoresizingFlexibleBottomMargin;

        closeButton.autoresizingMask = UIViewAutoresizingNone;
    }
}

- (void)displayWindow {

    //faux view
    UIView *fauxView = [[UIView alloc] initWithFrame: self.bgView.bounds];
    fauxView.autoresizesSubviews = YES;
    fauxView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.bgView addSubview:fauxView];
    
    //animation options
    UIViewAnimationOptions options = UIViewAnimationOptionTransitionCrossDissolve |
                                     UIViewAnimationOptionAllowUserInteraction    |
                                     UIViewAnimationOptionBeginFromCurrentState;
    
    [self constructWindow];
    
    //run the animation
    [UIView transitionFromView:fauxView toView:self.bigPanelView duration:0.5 options:options completion: ^(BOOL finished) {
        
        //dim the contents behind the popup window
        UIView *shadeView = [[UIView alloc] initWithFrame:self.bigPanelView.bounds];
        shadeView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        shadeView.backgroundColor = [UIColor blackColor];
        shadeView.alpha = 0.3;
        shadeView.tag = kShadeViewTag;

        [self.bigPanelView addSubview:shadeView];
        [self.bigPanelView sendSubviewToBack:shadeView];
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

/**
 * Removes the shade background and calls the finish selector
 */
- (void)closePopupWindow {
    //remove the shade
    [[self.bigPanelView viewWithTag:kShadeViewTag] removeFromSuperview];
    [self performSelector:@selector(finish) withObject:nil afterDelay:0.1];
}

/**
 * Removes child views from bigPanelView and bgView
 */
- (void)removeChildViews {
    for (UIView *child in self.bigPanelView.subviews) {
        [child removeFromSuperview];
    }
    for (UIView *child in self.bgView.subviews) {
        [child removeFromSuperview];
    }
}


/**
 * Removes all views from the hierarchy and releases self
 */
- (void)finish {

    //faux view
    UIView *fauxView = [[UIView alloc] initWithFrame:CGRectMake(10, 10, 200, 200)];
    [self.bgView addSubview:fauxView];
    
    //run the animation
    UIViewAnimationOptions options = UIViewAnimationOptionTransitionCrossDissolve |
                                        UIViewAnimationOptionAllowUserInteraction |
                                        UIViewAnimationOptionBeginFromCurrentState;

    [UIView transitionFromView:self.bigPanelView toView:fauxView duration:0.5 options:options completion:^(BOOL finished) {
        [self removeChildViews];
        self.bigPanelView = nil;
        [self.bgView removeFromSuperview];
        [overlayControllers removeObject:self];
    }];

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
