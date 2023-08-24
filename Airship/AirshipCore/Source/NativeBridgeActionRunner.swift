/* Copyright Airship and Contributors */

#if !os(tvOS) && !os(watchOS)

import WebKit

/// Action runner used in the `NativeBridge`.
public protocol NativeBridgeActionRunner {
    /// Called to run an action when triggered from the web view.
    ///  - Parameters:
    ///     - actionName: The action name.
    ///     - arguments: The action arguments.
    ///     - webView: The web view.
    /// - Returns: The action result.
    @MainActor
    func runAction(actionName: String, arguments: ActionArguments, webView: WKWebView) async -> ActionResult
}

#endif
