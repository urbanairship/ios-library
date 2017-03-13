/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

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

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

#import "UAWebViewCallData.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Base class for UIWebView & WKWebView native bridges that automatically inject the 
 * Urban Airship Javascript interface on whitelisted URLs.
 */
@interface UABaseNativeBridge()

/**
 * Populate Javascript environment if the webView is showing a whitelisted URL.
 *
 * @param webView The UIWebView or WKWebView.
 */
- (void)populateJavascriptEnvironmentIfWhitelisted:(UIView *)webView requestURL:(NSURL *)url;

/**
 * Call the appropriate Javascript delegate with the call data and evaluate the returned Javascript.
 *
 * @param data The object holding the data associated with JS delegate calls .
 * @param webView The UIWebView or WKWebView.
 */
- (void)performJSDelegateWithData:(UAWebViewCallData *)data webView:(UIView *)webView;

/**
 * Handles a link click.
 *
 * @param url The link's URL.
 * @returns YES if the link was handled, otherwise NO.
 */
- (BOOL)handleLinkClick:(NSURL *)url;

/**
 * Test if request's URL is an Airship URL and is whitelisted.
 *
 * @param request The request.
 * @returns YES if the request is both an Airship URL and is whitelisted, otherwise NO.
 */
- (BOOL)isWhiteListedAirshipRequest:(NSURLRequest *)request;

@end

NS_ASSUME_NONNULL_END
