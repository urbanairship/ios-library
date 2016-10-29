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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "UARichContentWindow.h"

@class UAInboxMessage;

NS_ASSUME_NONNULL_BEGIN

/**
 * This class provides an interface for displaying overlay window over
 * the app's UI without totally obscuring it, which loads a landing
 * page in an embedded UIWebView.
 */
@interface UALandingPageOverlayController : NSObject<UIWebViewDelegate, UARichContentWindow>

/**
 * Creates and displays a landing page overlay from a URL.
 * @param url The URL of the landing page to display.
 * @param headers The headers to include with the request.
 */
+ (void)showURL:(NSURL *)url withHeaders:(nullable NSDictionary *)headers;

/**
 * Creates and displays a landing page overlay from a URL.
 * @param url The URL of the landing page to display.
 * @param headers The headers to include with the request.
 * @param size The size of the landing page in points, full screen by default.
 * @param aspectLock Locks messages to provided size's aspect ratio.
 */
+ (void)showURL:(NSURL *)url withHeaders:(nullable NSDictionary *)headers size:(CGSize)size aspectLock:(BOOL)aspectLock;

/**
 * Creates and displays a landing page overlay from a Rich Push message.
 * @param message The Rich Push message to display.
 * @param headers The headers to include with the request.
 */
+ (void)showMessage:(UAInboxMessage *)message withHeaders:(nullable NSDictionary *)headers;

/**
 * Creates and displays a landing page overlay from a Rich Push message.
 * @param message The Rich Push message to display.
 * @param headers The headers to include with the request.
 * @param size The size of the message in points, full screen by default.
 * @param aspectLock Locks messages to provided size's aspect ratio.
 */
+ (void)showMessage:(UAInboxMessage *)message withHeaders:(nullable NSDictionary *)headers size:(CGSize)size aspectLock:(BOOL)aspectLock;

/**
 * Creates and displays a landing page overlay from a Rich Push message.
 * @param message The Rich Push message to display.
 */
+ (void)showMessage:(UAInboxMessage *)message;

/**
 * Closes all currently displayed overlays.
 * @param animated Indicates whether to animate the close transition.
 */
+ (void)closeAll:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
