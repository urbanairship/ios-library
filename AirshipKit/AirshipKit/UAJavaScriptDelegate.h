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

#import <Foundation/Foundation.h>

@class UAWebViewCallData;

NS_ASSUME_NONNULL_BEGIN

/**
 * A completion handler used to pass the result of a UAJavaScriptDelegate call.
 * The value passed may be nil.
 */
typedef void (^UAJavaScriptDelegateCompletionHandler)(NSString * __nullable script);

/**
 * A standard protocol for accessing native Objective-C functionality from webview
 * content.
 *
 * UADefaultJSDelegate is a reference implementation of this protocol.
 */
@protocol UAJavaScriptDelegate <NSObject>

@required

/**
 * Delegates must implement this method. Implementations take a model object representing
 * call data, which includes the command name, an array of string arguments,
 * and a dictionary of key-value pairs (all strings). After processing them, they pass a string
 * containing Javascript that will be evaluated in a message's UIWebView.
 *
 * If the passed command name is not one the delegate responds to, or if no JavaScript side effect
 * is desired, it implementations should pass nil.
 *
 * To pass information to the delegate from a webview, insert links with a "uairship" scheme,
 * args in the path and key-value option pairs in the query string. The host
 * portion of the URL is treated as the command name.
 *
 * The basic URL format:
 * uairship://command-name/<args>?<key/value options>
 *
 * For example, to invoke a command named "foo", and pass in three args (arg1, arg2 and arg3)
 * and three key-value options {option1:one, option2:two, option3:three}:
 *
 * uairship://foo/arg1/arg2/arg3?option1=one&amp;option2=two&amp;option3=three
 *
 * The default, internal implementation of this protocol is UAActionJSDelegate.
 * UAActionJSDelegate reserves command names associated with running Actions, and
 * handles those commands exclusively.
 *
 * @param data An instance of `UAWebViewCallData`
 * @param completionHandler A completion handler to be called with the resulting
 * string to be executed back in the JS environment.
 */
- (void)callWithData:(UAWebViewCallData *)data
   withCompletionHandler:(UAJavaScriptDelegateCompletionHandler)completionHandler;

@end

NS_ASSUME_NONNULL_END
