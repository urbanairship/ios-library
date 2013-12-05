
#import <Foundation/Foundation.h>

@class UAWebViewCallbackData;

/**
 * A completion handler used to pass the result of a UAJavaScriptDelegate callback.
 * The value passed may be nil.
 */
typedef void (^UAJavaScriptDelegateCompletionHandler)(NSString *script);

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
 * callback data, which includes the callback name, an array of string arguments,
 * and a dictionary of key-value pairs (all strings). After processing them, they pass a string
 * containing Javascript that will be evaluated in a message's UIWebView.
 *
 * If the passed callback name is not one the delegate responds to, or if no JavaScript side effect
 * is desired, it implementations should pass nil.
 *
 * To pass information to the delegate from a webview, insert links with a "ua" scheme,
 * args in the path and key-value option pairs in the query string. The host
 * portion of the URL is treated as the callback name.
 *
 * The basic URL format:
 * ua://callback-name/<args>?<key/value options>
 *
 * For example, to invoke a callback named "foo", and pass in three args (arg1, arg2 and arg3) 
 * and three key-value options {option1:one, option2:two, option3:three}:
 *
 * ua://foo/arg1/arg2/arg3?option1=one&amp;option2=two&amp;option3=three
 *
 * The default, internal implementation of this protocol is UAActionJSDelegate.
 * UAActionJSDelegate reserves callback names associated with running Actions, and
 * handles those callbacks exclusively.
 *
 * @param data An instance of `UAWebViewCallbackData`
 * @param completionHandler A completion handler to be called with the resulting
 * string to be executed back in the JS environment.
 */
- (void)callbackWithData:(UAWebViewCallbackData *)data
   withCompletionHandler:(UAJavaScriptDelegateCompletionHandler)completionHandler;

@end
