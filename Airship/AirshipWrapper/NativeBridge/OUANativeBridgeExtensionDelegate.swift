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
        _ js: OUAJavaScriptEnvironment,
        webView: WKWebView
    ) async

}

public class OUANativeBridgeExtensionDelegateWrapper: NSObject, NativeBridgeExtensionDelegate {
    private let delegate: OUANativeBridgeExtensionDelegate
    
    init(delegate: OUANativeBridgeExtensionDelegate) {
        self.delegate = delegate
    }
    
    public func actionsMetadata(for command: JavaScriptCommand, webView: WKWebView) -> [String : String] {
        self.delegate.actionsMetadata(for: command, webView: webView)
    }
    
    public func extendJavaScriptEnvironment(_ js: JavaScriptEnvironmentProtocol, webView: WKWebView) async {
        let jse = OUAJavaScriptEnvironment(delegate: js)
        await self.delegate.extendJavaScriptEnvironment(jse, webView: webView)
    }
}

@objc
public class OUAJavaScriptEnvironment: NSObject {
    private let delegate: JavaScriptEnvironmentProtocol
    
    init(delegate: JavaScriptEnvironmentProtocol) {
        self.delegate = delegate
    }
   
    @objc(addStringGetter:value:)
    func add(_ getter: String, string: String?) {
        self.delegate.add(getter, string: string)
    }
    
    @objc(addNumberGetter:value:)
    func add(_ getter: String, number: NSNumber?) {
        self.delegate.add(getter, number: number)
    }

    @objc(addDictionaryGetter:value:)
    func add(_ getter: String, dictionary: [AnyHashable: Any]?) {
        self.delegate.add(getter, dictionary: dictionary)
    }

    @objc
    func build() async -> String {
        await self.delegate.build()
    }
}


#endif
