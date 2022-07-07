/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

#if !TARGET_OS_TV && !TARGET_OS_WATCH

#import <WebKit/WebKit.h>

@class UAJavaScriptCommand;
@protocol UAJavaScriptEnvironmentProtocol;

NS_ASSUME_NONNULL_BEGIN

/**
 * Delegate to extend the native bridge.
 */
NS_SWIFT_NAME(NativeBridgeExtensionDelegate)
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
- (void)extendJavaScriptEnvironment:(id<UAJavaScriptEnvironmentProtocol>)js webView:(WKWebView *)webView;

@end

NS_ASSUME_NONNULL_END

#endif
