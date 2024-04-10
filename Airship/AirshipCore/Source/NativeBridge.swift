/* Copyright Airship and Contributors */

#if canImport(AirshipBasement)
import AirshipBasement
#endif

#if !os(tvOS) && !os(watchOS)

import Foundation
import WebKit

/// The native bridge will automatically load the Airship JavaScript environment into whitlelisted sites. The native
/// bridge must be assigned as the navigation delegate on a `WKWebView` in order to function.
@objc(UANativeBridge)
public class NativeBridge: NSObject, WKNavigationDelegate {
    static let airshipScheme = "uairship"
    private static let closeCommand = "close"
    private static let setNamedUserCommand = "named_user"
    private static let multiCommand = "multi"

    private var jsRequests: [JSBridgeLoadRequest] = []

    private static let forwardSchemes = [
        "itms-apps", "maps", "sms", "tel", "mailto",
    ]

    private static let forwardHosts = [
        "maps.google.com",
        "www.youtube.com",
        "phobos.apple.com",
        "itunes.apple.com",
    ]

    /// Delegate to support additional native bridge features such as `close`.
    @objc
    public weak var nativeBridgeDelegate: NativeBridgeDelegate?

    /// Optional delegate to forward any WKNavigationDelegate calls.
    @objc
    public weak var forwardNavigationDelegate: UANavigationDelegate?

    /// Optional delegate to support custom JavaScript commands.
    @objc
    public weak var javaScriptCommandDelegate: JavaScriptCommandDelegate?

    /// Optional delegate to extend the native bridge.
    @objc
    public weak var nativeBridgeExtensionDelegate: NativeBridgeExtensionDelegate?

    private let actionHandler: NativeBridgeActionHandlerProtocol
    private let javaScriptEnvironmentFactoryBlock: () -> JavaScriptEnvironmentProtocol

    /// NativeBridge initializer.
    /// - Note: For internal use only. :nodoc:
    /// - Parameter actionHandler: An action handler.
    /// - Parameter javaScriptEnvironmentFactoryBlock: A factory block producing a JavaScript environment.
    init(
        actionHandler: NativeBridgeActionHandlerProtocol,
        javaScriptEnvironmentFactoryBlock: @escaping () -> JavaScriptEnvironmentProtocol
    ) {
        self.actionHandler = actionHandler
        self.javaScriptEnvironmentFactoryBlock =
            javaScriptEnvironmentFactoryBlock
        super.init()
    }

    /// NativeBridge initializer.
    @objc
    public convenience override init() {
        self.init(
            actionHandler: NativeBridgeActionHandler(),
            javaScriptEnvironmentFactoryBlock: {
                return JavaScriptEnvironment()
            }
        )
    }

    /// NativeBridge initializer.
    /// - Parameter actionRunner: An action runner to run actions triggered from the web view
    public convenience init(actionRunner: NativeBridgeActionRunner) {
        self.init(
            actionHandler: NativeBridgeActionHandler(actionRunner: actionRunner),
            javaScriptEnvironmentFactoryBlock: {
                return JavaScriptEnvironment()
            }
        )
    }

    /**
     * Decide whether to allow or cancel a navigation. :nodoc:
     *
     * If a uairship:// URL, process it ourselves
     */
    public func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        let navigationType = navigationAction.navigationType
        let originatingURL = webView.url
        let requestURL = navigationAction.request.url

        let isAirshipJSAllowed =
            originatingURL?.isAllowed(scope: .javaScriptInterface) ?? false

        // Airship commands
        if let requestURL = requestURL, isAirshipJSAllowed, requestURL.isAirshipCommand {
            if navigationType == .linkActivated || navigationType == .other {
                let command = JavaScriptCommand(url: requestURL)
                Task { @MainActor in
                    await self.handleAirshipCommand(
                        command: command,
                        webView: webView
                    )
                }
            }
            decisionHandler(.cancel)
            return
        }

        let forward =
            self.forwardNavigationDelegate?.webView
            as (
                (
                    WKWebView, WKNavigationAction,
                    @escaping (WKNavigationActionPolicy) -> Void
                ) -> Void
            )?

        // Forward
        if let forward = forward {
            forward(webView, navigationAction) { policyForThisURL in
                if policyForThisURL == WKNavigationActionPolicy.allow
                    && navigationType == WKNavigationType.linkActivated
                {
                    let decisionHandlerWrapper = AirshipUnsafeSendableWrapper(decisionHandler)
                    Task { @MainActor in
                        // Try to override any special link handling
                        self.handle(requestURL) { success in
                            decisionHandlerWrapper.value(success ? .cancel : .allow)
                        }
                    }
                } else {
                    decisionHandler(policyForThisURL)
                }
            }
            return
        }

        // Default
        guard let requestURL = requestURL else {
            decisionHandler(.allow)
            return
        }

        // Default
        let handleLink: () -> Void = {
            /// If target frame is a new window navigation, have OS handle it
            if navigationAction.targetFrame == nil {
                UIApplication.shared.open(
                    requestURL,
                    options: [:],
                    completionHandler: { success in
                        decisionHandler(success ? .cancel : .allow)
                    }
                )
            } else {
                decisionHandler(.allow)
            }
        }

        if navigationType == WKNavigationType.linkActivated {
            let decisionHandlerWrapper = AirshipUnsafeSendableWrapper(decisionHandler)
            let handleLinkWrapper = AirshipUnsafeSendableWrapper(handleLink)

            Task { @MainActor in
                self.handle(requestURL) { success in
                    if success {
                        decisionHandlerWrapper.value(.cancel)
                    } else {
                        handleLinkWrapper.value()
                    }
                }
            }

        } else {
            handleLink()
        }
    }

    /**
     * Decide whether to allow or cancel a navigation after its response is known. :nodoc:
     */
    public func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {

        guard
            let forward = self.forwardNavigationDelegate?.webView
                as (
                    (
                        WKWebView, WKNavigationResponse,
                        @escaping (WKNavigationResponsePolicy) -> Void
                    ) -> Void
                )?
        else {
            decisionHandler(.allow)
            return
        }

        forward(webView, navigationResponse, decisionHandler)
    }

    /**
     * Called when the navigation is complete. :nodoc:
     */
    @MainActor
    public func webView(
        _ webView: WKWebView,
        didFinish navigation: WKNavigation!
    ) {
        AirshipLogger.trace(
            "Webview finished navigation: \(String(describing: webView.url))"
        )

        cancelJSRequest(webView: webView)

        if let url = webView.url, url.isAllowed(scope: .javaScriptInterface) {
            AirshipLogger.trace("Loading Airship JS bridge: \(url)")

            let request = JSBridgeLoadRequest(webView: webView) { [weak self] in
                return await self?.makeJSEnvironment(webView: webView)
            }
            self.jsRequests.append(request)
            request.start()
        }

        self.forwardNavigationDelegate?.webView?(
            webView,
            didFinish: navigation
        )
    }

    /**
     * Called when the web view begins to receive web content. :nodoc:
     */
    public func webView(
        _ webView: WKWebView,
        didCommit navigation: WKNavigation!
    ) {
        self.forwardNavigationDelegate?.webView?(
            webView,
            didCommit: navigation
        )
    }

    /**
     * Called when the web view’s web content process is terminated. :nodoc:
     */
    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        self.forwardNavigationDelegate?
            .webViewWebContentProcessDidTerminate?(
                webView
            )
    }

    /**
     * Called when web content begins to load in a web view. :nodoc:
     */
    @MainActor
    public func webView(
        _ webView: WKWebView,
        didStartProvisionalNavigation navigation: WKNavigation!
    ) {
        self.cancelJSRequest(webView: webView)
        self.forwardNavigationDelegate?.webView?(
            webView,
            didStartProvisionalNavigation: navigation
        )
    }

    /**
     * Called when a web view receives a server redirect. :nodoc:
     */
    public func webView(
        _ webView: WKWebView,
        didReceiveServerRedirectForProvisionalNavigation navigation:
            WKNavigation!
    ) {
        self.forwardNavigationDelegate?.webView?(
            webView,
            didReceiveServerRedirectForProvisionalNavigation: navigation
        )
    }

    /**
     * Called when an error occurs during navigation. :nodoc:
     */
    public func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        self.forwardNavigationDelegate?.webView?(
            webView,
            didFail: navigation,
            withError: error
        )
    }

    /**
     * Called when an error occurs while the web view is loading content. :nodoc:
     */
    public func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        self.forwardNavigationDelegate?.webView?(
            webView,
            didFailProvisionalNavigation: navigation,
            withError: error
        )
    }

    /**
     * Called when the web view needs to respond to an authentication challenge. :nodoc:
     */
    public func webView(
        _ webView: WKWebView,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (
            URLSession.AuthChallengeDisposition, URLCredential?
        ) -> Void
    ) {

        guard
            let forward = self.forwardNavigationDelegate?.webView
                as (
                    (
                        WKWebView, URLAuthenticationChallenge,
                        @escaping (
                            URLSession.AuthChallengeDisposition,
                            URLCredential?
                        ) ->
                            Void
                    ) -> Void
                )?
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        forward(webView, challenge, completionHandler)
    }

    @MainActor
    private func makeJSEnvironment(webView: WKWebView) async -> String {
        let jsEnvironment: JavaScriptEnvironmentProtocol = self.javaScriptEnvironmentFactoryBlock()

        await self.nativeBridgeExtensionDelegate?.extendJavaScriptEnvironment(
            jsEnvironment,
            webView: webView
        )

        return await jsEnvironment.build()
    }

    @MainActor
    private func handleAirshipCommand(
        command: JavaScriptCommand,
        webView: WKWebView
    ) async {
        switch command.name {
        case NativeBridge.closeCommand:
            self.nativeBridgeDelegate?.close()

        case NativeBridge.setNamedUserCommand:
            let idArgs = command.options["id"]
            let argument = idArgs?.first

            let contact: AirshipContactProtocol = Airship.contact
            if let identifier = argument, !identifier.isEmpty {
                contact.identify(identifier)
            } else {
                contact.reset()
            }

        case NativeBridge.multiCommand:
            let commands = command.url.query?.components(separatedBy: "&")
                .compactMap {
                    URL(string: $0.removingPercentEncoding ?? "")
                }
                .filter {
                    $0.isAirshipCommand
                }.compactMap { url in
                    JavaScriptCommand(url: url)
                } ?? []

            for command in commands {
                await self.handleAirshipCommand(
                    command: command,
                    webView: webView
                )
            }
        default:
            if NativeBridgeActionHandler.isActionCommand(command: command) {
                let metadata = self.nativeBridgeExtensionDelegate?
                    .actionsMetadata(
                        for: command,
                        webView: webView
                    )

                let script = await self.actionHandler.runActionsForCommand(
                    command: command,
                    metadata: metadata,
                    webView: webView
                )

                do {
                    if let script = script {
                        try await webView.evaluateJavaScriptAsync(script)
                    }
                } catch {
                    AirshipLogger.error("JavaScript error: \(error) command: \(command)")
                }
            } else if !forwardAirshipCommand(command, webView: webView) {
                AirshipLogger.debug("Unhandled JavaScript command: \(command)")
            }
        }
    }

    @MainActor
    private func forwardAirshipCommand(
        _ command: JavaScriptCommand,
        webView: WKWebView
    ) -> Bool {
        /// Local JavaScript command delegate
        if self.javaScriptCommandDelegate?
            .performCommand(command, webView: webView)
            == true
        {
            return true
        }

        if Airship.javaScriptCommandDelegate?
            .performCommand(
                command,
                webView: webView
            ) == true
        {
            return true
        }

        return false
    }

    @MainActor
    private func cancelJSRequest(webView: WKWebView) {
        jsRequests.removeAll { request in
            if request.webView == nil || request.webView == webView {
                request.cancel()
                return true
            }
            return false
        }
    }
    /**
     * Handles a link click.
     *
     * - Parameters:
     *   - url The link's URL.
     *   - completionHandler  The completion handler to execute when openURL processing is complete.
     * -
     */
    @available(iOSApplicationExtension, unavailable)
    @MainActor
    private func handle(
        _ url: URL?,
        _ completionHandler: @escaping (Bool) -> Void
    ) {
        guard let url = url, shouldForwardURL(url) else {
            completionHandler(false)
            return
        }

        UIApplication.shared.open(url, options: [:]) { success in
            /// Its better to return YES here and no-op on these links instead of reporting an unhandled URL
            /// to avoid the message thinking it failed to load. The only time a NO will happen is on a simulator
            /// without access to the app store.
            completionHandler(true)
        }
    }

    private func shouldForwardURL(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased() ?? ""
        let host = url.host?.lowercased() ?? ""
        return NativeBridge.forwardSchemes.contains(scheme)
            || NativeBridge.forwardHosts.contains(host)
    }

    private func closeWindow(_ animated: Bool) {
        self.forwardNavigationDelegate?.closeWindow?(animated)
    }
}

@objc
public protocol UANavigationDelegate: WKNavigationDelegate {
    @objc optional func closeWindow(_ animated: Bool)
}

extension URL {
    fileprivate var isAirshipCommand: Bool {
        return self.scheme == NativeBridge.airshipScheme
    }

    fileprivate func isAllowed(scope: URLAllowListScope) -> Bool {
        return Airship.urlAllowList.isAllowed(self, scope: scope)
    }
}


@MainActor
fileprivate class JSBridgeLoadRequest: Sendable {
    private(set) weak var webView: WKWebView?
    private let jsFactoryBlock: () async throws -> String?
    private var task: Task<Void, Never>?

    init(webView: WKWebView? = nil, jsFactoryBlock: @escaping () async throws -> String?) {
        self.webView = webView
        self.jsFactoryBlock = jsFactoryBlock
    }

    func start() {
        task?.cancel()
        self.task = Task { @MainActor in
            do {
                try Task.checkCancellation()
                let js = try await jsFactoryBlock()
                try Task.checkCancellation()
                if let webView = webView, let js = js {
                    try await webView.evaluateJavaScript(js)
                    AirshipLogger.trace("Native bridge injected")
                }
            } catch {

            }
        }
    }

    func cancel() {
        self.task?.cancel()
    }
}

fileprivate extension WKWebView {

    //The async/await version of `evaluateJavaScript` function exposed by apple is crashing when the JavaScript is a void method. We created this func to avoid the crash and we can update once the crash is fixed.
    @discardableResult
    func evaluateJavaScriptAsync(_ str: String) async throws -> Any? {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Any?, Error>) in
            DispatchQueue.main.async {
                self.evaluateJavaScript(str) { data, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: data)
                    }
                }
            }
        }
    }
    
}

#endif
