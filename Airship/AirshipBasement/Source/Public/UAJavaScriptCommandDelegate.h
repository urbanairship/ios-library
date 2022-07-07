/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

@class UAJavaScriptCommand;

#if !TARGET_OS_TV && !TARGET_OS_WATCH

#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A standard protocol for handling commands from the native brige.
 */
API_UNAVAILABLE(tvos)
NS_SWIFT_NAME(JavaScriptCommandDelegate)
@protocol UAJavaScriptCommandDelegate <NSObject>

@required

/**
 * Delegates must implement this method. Implementations take a model object representing
 * the JavaScript command which includes the command name, an array of string arguments,
 * and a dictionary of key-value pairs (all strings).
 *
 * If the passed command name is not one the delegate responds to return `NO`. If the command is handled, return
 * `YES` and the command will not be handled by another delegate.
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
 * *
 * @param command An instance of `UAJavaScriptCommand`
 * @param webView The web view.
 * @return `YES` if the command was handled, otherwise `NO`.
 */
- (BOOL)performCommand:(UAJavaScriptCommand *)command webView:(WKWebView *)webView;

@end

NS_ASSUME_NONNULL_END

#endif
