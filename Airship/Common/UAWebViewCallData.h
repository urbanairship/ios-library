
#import <Foundation/Foundation.h>

@class UAInboxMessage;

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
+ (UAWebViewCallData *)callDataForURL:(NSURL *)url webView:(UIWebView *)webView message:(UAInboxMessage *)message;

/**
 * A name, derived from the host passed in the delegate call URL.
 * This is typically the name of a command.
 */
@property (nonatomic, copy) NSString *name;

/**
 * The argument strings passed in the call.
 */
@property (nonatomic, strong) NSArray *arguments;

/**
 * The query options passed in the call.
 */
@property (nonatomic, strong) NSDictionary *options;

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
@property (nonatomic, strong) UAInboxMessage *message;

@end
