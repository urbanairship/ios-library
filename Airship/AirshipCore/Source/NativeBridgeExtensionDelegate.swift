/* Copyright Airship and Contributors */


#if !os(tvOS) && !os(watchOS)


public import WebKit

/// Delegate to extend the native bridge.
public protocol NativeBridgeExtensionDelegate: AnyObject {

    /// Called when an action is triggered from the JavaScript Environment. This method should return the metadata used in the `ActionArgument`.
    /// - Parameter command The JavaScript command.
    /// - Parameter webView The webview.
    /// @return The action metadata.
    @MainActor
    func actionsMetadata(
        for command: JavaScriptCommand,
        webView: WKWebView
    ) -> [String: String]

    /// Called before the JavaScript environment is being injected into the web view.
    /// - Parameter js The JavaScript environment.
    /// - Parameter webView  The web view.
    /// - Parameter completionHandler The completion handler when finished.
    @MainActor
    func extendJavaScriptEnvironment(
        _ js: any JavaScriptEnvironmentProtocol,
        webView: WKWebView
    ) async
}

#endif
