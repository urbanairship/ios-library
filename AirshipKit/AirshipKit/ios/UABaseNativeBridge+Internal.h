/* Copyright Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

#import "UAWebViewCallData.h"
#import "UAJavaScriptDelegate.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * The UAirship scheme.
 */
extern NSString *const UANativeBridgeUAirshipScheme;

/**
 * The dismiss command.
 */
extern NSString *const UANativeBridgeDismissCommand;

/**
 * Base class for UIWebView & WKWebView native bridges that automatically inject the 
 * Urban Airship Javascript interface on whitelisted URLs.
 */
@interface UABaseNativeBridge()

///---------------------------------------------------------------------------------------
/// @name Base Native Bridge Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Populate Javascript environment if the webView is showing a whitelisted URL.
 *
 * @param webView The UIWebView or WKWebView.
 * @param url The request URL.
 * @param completionHandler A completion handler to be called when the environment is fully populated.
 */
- (void)populateJavascriptEnvironmentIfWhitelisted:(UIView *)webView requestURL:(NSURL *)url completionHandler:(void (^)(void))completionHandler;

/**
 * Call the appropriate Javascript delegate with the call data and evaluate the returned Javascript.
 *
 * @param data The object holding the data associated with JS delegate calls .
 * @param webView The UIWebView or WKWebView.
 */
- (void)performJSDelegateWithData:(UAWebViewCallData *)data webView:(UIView *)webView;

/**
 * Call the provided Javascript delegate with the call data and evaluate the returned Javascript.
 */
- (void)performAsyncJSCallWithDelegate:(id<UAJavaScriptDelegate>)delegate
                                  data:(UAWebViewCallData *)data
                               webView:(UIView *)webView;

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
 * @param originatingURL The URL the request was made from.
 * @returns YES if the request is both an Airship URL and is whitelisted, otherwise NO.
 */
- (BOOL)isWhiteListedAirshipRequest:(NSURLRequest *)request originatingURL:(NSURL *)originatingURL;

@end

NS_ASSUME_NONNULL_END
