/* Copyright Airship and Contributors */

#if !os(tvOS) && !os(watchOS)

import Foundation
import WebKit
import AirshipCore

/// Delegate to extend the native bridge.
@objc
public protocol OUANativeBridgeExtensionDelegate {

    /// Called when an action is triggered from the JavaScript Environment. This method should return the metadata used in the `ActionArgument`.
    /// - Parameter command The JavaScript command.
    /// - Parameter webView The webview.
    /// @return The action metadata.
    @objc(actionsMetadataForCommand:webView:)
    @MainActor
    func actionsMetadata(
        for command: JavaScriptCommand,
        webView: WKWebView
    ) -> [String: String]

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

public class OUANativeBridgeExtensionDelegateWrapper: NSObject, NativeBridgeExtensionDelegate {
    private let delegate: OUANativeBridgeExtensionDelegate
    
    init(delegate: OUANativeBridgeExtensionDelegate) {
        self.delegate = delegate
    }
    
    public func actionsMetadata(for command: AirshipCore.JavaScriptCommand, webView: WKWebView) -> [String : String] {
        self.delegate.actionsMetadata(for: command, webView: webView)
    }
    
    public func extendJavaScriptEnvironment(_ js: JavaScriptEnvironmentProtocol, webView: WKWebView) async {
        await self.delegate.extendJavaScriptEnvironment(js, webView: webView)
    }
}

#endif
