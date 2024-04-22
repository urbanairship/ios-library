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


/// Action runner used in the `NativeBridge` that calls through to a block.
public struct BlockNativeBridgeActionRunner: NativeBridgeActionRunner {
    private let onRun: @MainActor (String, ActionArguments, WKWebView) async -> ActionResult


    /// Default initialiizer.
    ///  - Parameters:
    ///     - onRun: The action block.
    public init(onRun: @escaping @MainActor (String, ActionArguments, WKWebView) async -> ActionResult) {
        self.onRun = onRun
    }

    @MainActor
    public func runAction(actionName: String, arguments: ActionArguments, webView: WKWebView) async -> ActionResult {
        return await self.onRun(actionName, arguments, webView)
    }
}

#endif
