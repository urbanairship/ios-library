/* Copyright Airship and Contributors */


#if !os(tvOS) && !os(watchOS)

import Foundation
import WebKit

/// Delegate to extend the native bridge.
@objc(UANativeBridgeExtensionDelegate)
public protocol NativeBridgeExtensionDelegate {

    /// Called when an action is triggered from the JavaScript Environment. This method should return the metadata used in the `ActionArguments`.
    /// - Parameter command The JavaScript command.
    /// - Parameter webView The webview.
    /// @return The action metadata.
    @objc(actionsMetadataForCommand:webView:)
    @MainActor
    func actionsMetadata(
        for command: JavaScriptCommand,
        webView: WKWebView
    ) -> [AnyHashable: Any]

    /// Called before the JavaScript environment is being injected into the web view.
    /// - Parameter js The JavaScript environment.
    /// - Parameter webView  The web view.
    /// - Parameter completionHandler The completion handler when finished.
    @objc
    @MainActor
    func extendJavaScriptEnvironment(
        _ js: JavaScriptEnvironmentProtocol,
        webView: WKWebView
    ) async
}

#endif
