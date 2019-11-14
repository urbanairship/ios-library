/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import "UAJavaScriptEnvironment.h"
#import "UAJavaScriptCommand.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Delegate to extend the native bridge.
 */
@protocol UANativeBridgeExtensionDelegate <NSObject>

@optional

/**
 * Called when an action is triggered from the JavaScript Environment. This method should return the metadata used in the `ActionArguments`.
 * @parm command The JavaScript command.
 * @param webView The webview.
 * @return The action metadata.
 */
- (NSDictionary *)actionsMetadataForCommand:(UAJavaScriptCommand *)command webView:(WKWebView *)webView;

/**
 * Called before the JavaScript environment is being injected into the web view.
 * @param js The JavaScript environment.
 * @param webView The web view.
 */
- (void)extendJavaScriptEnvironment:(UAJavaScriptEnvironment *)js webView:(WKWebView *)webView;

@end

NS_ASSUME_NONNULL_END

