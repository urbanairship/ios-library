
#import <Foundation/Foundation.h>

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
 * Delegates must implement this method. Implementations take an array of string arguments
 * and a dictionary of key-value pairs (all strings), process them, and pass a string
 * containing Javascript that will be evaluated in a message's UIWebView.
 *
 * To pass information to the delegate from a message, insert links with a "ua" scheme,
 * args in the path and key-value option pairs in the query string. The host
 * portion of the URL is ignored.
 *
 * The basic URL format:
 * ua://callback/<args>?<key/value options>
 *
 * For example, to pass in three args (arg1, arg2 and arg3) and three key-value
 * options {option1:one, option2:two, option3:three}:
 * ua://callback/arg1/arg2/arg3?option1=one&amp;option2=two&amp;option3=three
 *
 * The default, internal implementation is UAActionJSDelegate.
 *
 * @param args An array of argument values
 * @param options A dictionary of key/value query parameters
 * @param completionHandler A completion handler to be called with the resulting
 * string to be executed back in the JS environment.
 */
- (void)callbackArguments:(NSArray *)args
              withOptions:(NSDictionary *)options
    withCompletionHandler:(UAJavaScriptDelegateCompletionHandler)completionHandler;

@end
