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

/* UAInboxOverlayController is based on MTPopupWindow by
 * Marin Todorov https://github.com/icanzilb + http://www.touch-code-magazine.com/
 *
 * Latest MTPopupWindow code: http://www.touch-code-magazine.com/showing-a-popup-window-in-ios6-modernized-tutorial-code-download/
 *
 * (Original version: http://www.touch-code-magazine.com/showing-a-popup-window-in-ios-class-for-download/ )
 *
 */

#import <Foundation/Foundation.h>

/**
 * This class provides an overlay window that can be popped over
 * the app's UI without totally obscuring it, and that loads a
 * given rich push message in an embedded UIWebView.  It is used
 * in the reference UI implementation for displaying in-app messages
 * without requiring navigation to the inbox.
 */
@interface UAKablamOverlayController : UIViewController<UIWebViewDelegate>

+ (void)showURL:(NSURL *)url;

+ (void)closeWindow:(BOOL)animated;

/**
 * Initializer, creates an overlay window and loads the given content within a particular view controller.
 * @param viewController the view controller to display the overlay in
 * @param messageID the message ID of the rich push message to display
 */
- (id)initWithParentViewController:(UIViewController *)parent andURL:(NSURL *)url;

@end
