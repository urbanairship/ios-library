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
#import <UIKit/UIKit.h>

@class UAInboxMessage;

NS_ASSUME_NONNULL_BEGIN

/**
 * Model object for holding data associated with JS delegate calls 
 */
@interface UAWebViewCallData : NSObject

/**
 * Processes a custom delegate call URL into associated call data.
 *
 * @param url The URL to be processed.
 * @param webView The UIWebView originating the call
 * @return An instance of UAWebViewCallData.
 */
+ (UAWebViewCallData *)callDataForURL:(NSURL *)url webView:(UIWebView *)webView;

/**
 * Processes a custom delegate call URL into associated call data.
 *
 * @param url The URL to be processed.
 * @param webView The UIWebView originating the call.
 * @param message The UAInboxMessage associated with the webview.
 * @return An instance of UAWebViewCallData.
 */
+ (UAWebViewCallData *)callDataForURL:(NSURL *)url webView:(UIWebView *)webView message:(nullable UAInboxMessage *)message;

/**
 * A name, derived from the host passed in the delegate call URL.
 * This is typically the name of a command.
 */
@property (nonatomic, copy, nullable) NSString *name;

/**
 * The argument strings passed in the call.
 */
@property (nonatomic, strong, nullable) NSArray<NSString *> *arguments;

/**
 * The query options passed in the call.
 */
@property (nonatomic, strong, nullable) NSDictionary *options;

/**
 * The UIWebView initiating the call.
 */
@property (nonatomic, strong) UIWebView *webView;

/**
 * The orignal URL that initiated the call.
 */
@property (nonatomic, strong) NSURL *url;

/**
 * The UAInboxMessage associated with the webview.
 */
@property (nonatomic, strong, nullable) UAInboxMessage *message;

@end

NS_ASSUME_NONNULL_END
