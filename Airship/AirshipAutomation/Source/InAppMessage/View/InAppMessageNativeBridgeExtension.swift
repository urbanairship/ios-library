/* Copyright Airship and Contributors */
#if !os(tvOS)
import Foundation
public import WebKit

#if canImport(AirshipCore)
public import AirshipCore
#endif

/// Airship native bridge extension for an InAppMessage
public class InAppMessageNativeBridgeExtension: NativeBridgeExtensionDelegate {

    private let message: InAppMessage

    /// Airship native bridge extension initializer
    /// - Parameter message: In-app message
    public init(message: InAppMessage) {
        self.message = message
    }

    public func actionsMetadata(
        for command: JavaScriptCommand,
        webView: WKWebView
    ) -> [String: String] {
        return [:]
    }

    public func extendJavaScriptEnvironment(
        _ js: JavaScriptEnvironmentProtocol,
        webView: WKWebView
    ) async {
        let extras = message.extras?.unWrap() as? [String : AnyHashable]

        js.add(
            "getMessageExtras",
            dictionary: extras ?? [:]
        )
    }
}
#endif
