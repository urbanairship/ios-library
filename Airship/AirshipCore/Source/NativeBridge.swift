/* Copyright Airship and Contributors */

#if canImport(AirshipBasement)
import AirshipBasement
#endif

#if !os(tvOS) && !os(watchOS)

import Foundation
import WebKit


/**
 * The native bridge will automatically load the Airship JavaScript environment into whitlelisted sites. The native
 * bridge must be assigned as the navigation delegate on a `WKWebView` in order to function.
 */
@objc(UANativeBridge)
public class NativeBridge : NSObject, WKNavigationDelegate {
    static let airshipScheme = "uairship"
    private static let closeCommand = "close"
    private static let setNamedUserCommand = "named_user"
    private static let multiCommand = "multi"
    
    private static let forwardSchemes = ["itms-apps", "maps", "sms", "tel", "mailto"]

    private static let forwardHosts = [
        "maps.google.com",
        "www.youtube.com",
        "phobos.apple.com",
        "itunes.apple.com"
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
    
    private var actionHandler: NativeBridgeActionHandlerProtocol
    private var javaScriptEnvironmentFactoryBlock: () -> JavaScriptEnvironmentProtocol

    /// NativeBridge initializer.
    /// - Note: For internal use only. :nodoc:
    /// - Parameter actionHandler: An action handler.
    /// - Parameter javaScriptEnvironmentFactoryBlock: A factory block producing a JavaScript environment.
    @objc(initWithActionHandler:javaScriptEnvironmentFactoryBlock:)
    public init(actionHandler: NativeBridgeActionHandlerProtocol, javaScriptEnvironmentFactoryBlock: @escaping () -> JavaScriptEnvironmentProtocol) {
        self.actionHandler = actionHandler
        self.javaScriptEnvironmentFactoryBlock = javaScriptEnvironmentFactoryBlock
        super.init()
    }

    /// NativeBridge initializer.
    @objc
    public convenience override init() {
        let actionHandler: NativeBridgeActionHandlerProtocol = NativeBridgeActionHandler.init()
        let javaScriptEnvironment: JavaScriptEnvironmentProtocol = JavaScriptEnvironment.init()
        self.init(actionHandler: actionHandler, javaScriptEnvironmentFactoryBlock: { return javaScriptEnvironment })
    }

    /**
     * Decide whether to allow or cancel a navigation. :nodoc:
     *
     * If a uairship:// URL, process it ourselves
     */
    @available(iOSApplicationExtension, unavailable)
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let navigationType = navigationAction.navigationType
        let originatingURL = webView.url
        let requestURL = navigationAction.request.url

        let isAirshipJSAllowed = originatingURL?.isAllowed(scope: .javaScriptInterface) ?? false

        // Airship commands
        if let requestURL = requestURL, isAirshipJSAllowed, requestURL.isAirshipCommand {
            if (navigationType == .linkActivated || navigationType == .other) {
                let command = JavaScriptCommand(for: requestURL)
                self.handleAirshipCommand(command: command, webView: webView)
            }
            decisionHandler(.cancel)
            return
        }

        let forward = self.forwardNavigationDelegate?.webView as ((WKWebView, WKNavigationAction, @escaping (WKNavigationActionPolicy) -> Void) -> Void)?

        // Forward
        if let forward = forward {
            forward(webView, navigationAction) { policyForThisURL in
                if (policyForThisURL == WKNavigationActionPolicy.allow && navigationType == WKNavigationType.linkActivated) {
                    // Try to override any special link handling
                    self.handle(requestURL) { success in
                        decisionHandler(success ? .cancel : .allow)
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
                UIApplication.shared.open(requestURL, options: [:], completionHandler: { success in
                    decisionHandler(success ? .cancel : .allow)
                })
            } else {
                decisionHandler(.allow)
            }
        }

        if (navigationType == WKNavigationType.linkActivated) {
            self.handle(requestURL) { success in
                if (success) {
                    decisionHandler(.cancel)
                } else {
                    handleLink()
                }
            }
        } else {
            handleLink()
        }
    }
    
    /**
     * Decide whether to allow or cancel a navigation after its response is known. :nodoc:
     */
    public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        
        guard let forward = self.forwardNavigationDelegate?.webView as ((WKWebView, WKNavigationResponse, @escaping (WKNavigationResponsePolicy) -> Void) -> Void)? else {
            decisionHandler(.allow)
            return
        }
        
        forward(webView, navigationResponse, decisionHandler)
    }
    
    /**
     * Called when the navigation is complete. :nodoc:
     */
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        AirshipLogger.trace("Webview finished navigation: \(String(describing: webView.url))")

        if let url = webView.url, url.isAllowed(scope: .javaScriptInterface) {
            AirshipLogger.trace("Populating Airship JS bridge: \(url)")
            let js: JavaScriptEnvironmentProtocol = self.javaScriptEnvironmentFactoryBlock()
            self.nativeBridgeExtensionDelegate?.extendJavaScriptEnvironment?(js, webView: webView)
            webView.evaluateJavaScript(js.build(), completionHandler: nil)
        }

        self.forwardNavigationDelegate?.webView?(webView, didFinish: navigation)
    }
    
    /**
     * Called when the web view begins to receive web content. :nodoc:
     */
    public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        self.forwardNavigationDelegate?.webView?(webView, didCommit: navigation)
    }
    
    /**
     * Called when the web view’s web content process is terminated. :nodoc:
     */
    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        self.forwardNavigationDelegate?.webViewWebContentProcessDidTerminate?(webView)
    }
    
    /**
     * Called when web content begins to load in a web view. :nodoc:
     */
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        self.forwardNavigationDelegate?.webView?(webView, didStartProvisionalNavigation: navigation)
    }
    
    /**
     * Called when a web view receives a server redirect. :nodoc:
     */
    public func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        self.forwardNavigationDelegate?.webView?(webView, didReceiveServerRedirectForProvisionalNavigation: navigation)
    }
    
    /**
     * Called when an error occurs during navigation. :nodoc:
     */
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.forwardNavigationDelegate?.webView?(webView, didFail: navigation, withError: error)
    }
    
    /**
     * Called when an error occurs while the web view is loading content. :nodoc:
     */
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        self.forwardNavigationDelegate?.webView?(webView, didFailProvisionalNavigation: navigation, withError: error)
    }

    /**
     * Called when the web view needs to respond to an authentication challenge. :nodoc:
     */
    public func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        guard let forward = self.forwardNavigationDelegate?.webView as ((WKWebView, URLAuthenticationChallenge, @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) -> Void)? else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        forward(webView, challenge, completionHandler)
    }

    private func handleAirshipCommand(command: JavaScriptCommand, webView: WKWebView) {
        switch (command.name) {
        case NativeBridge.closeCommand:
            self.nativeBridgeDelegate?.close()

        case NativeBridge.setNamedUserCommand:
            let idArgs = command.options["id"] as? [String]
            let argument = idArgs?.first

            let contact: ContactProtocol = Airship.contact
            if let identifier = argument, !identifier.isEmpty {
                contact.identify(identifier)
            } else {
                contact.reset()
            }

        case NativeBridge.multiCommand:
            command.url.query?.components(separatedBy: "&")
                .compactMap {
                    URL(string: $0.removingPercentEncoding ?? "")
                }.filter {
                    $0.isAirshipCommand
                }.forEach {
                    let command = JavaScriptCommand(for: $0)
                    self.handleAirshipCommand(command: command, webView: webView)
                }

        default:
            if (NativeBridgeActionHandler.isActionCommand(command: command)) {
                let metadata = self.nativeBridgeExtensionDelegate?.actionsMetadata?(for: command, webView: webView)
                self.actionHandler.runActionsForCommand(command: command, metadata: metadata, completionHandler: { script in
                    if let script = script {
                        webView.evaluateJavaScript(script, completionHandler: nil)
                    }
                })
            } else if (!forwardAirshipCommand(command, webView: webView)) {
                AirshipLogger.debug(String(format: "Unhandled JavaScript command: %@", command))
            }
        }
    }

    private func forwardAirshipCommand(_ command: JavaScriptCommand, webView: WKWebView) -> Bool {
        /// Local JavaScript command delegate
        if (self.javaScriptCommandDelegate?.perform(command, webView: webView) == true) {
            return true
        }


        if (Airship.shared.javaScriptCommandDelegate?.perform(command, webView: webView) == true) {
            return true
        }

        return false
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
    private func handle(_ url: URL?, _ completionHandler: @escaping (Bool) -> Void ) {
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
        return NativeBridge.forwardSchemes.contains(scheme) ||  NativeBridge.forwardHosts.contains(host)
    }
    
    private func closeWindow(_ animated: Bool) {
        self.forwardNavigationDelegate?.closeWindow?(animated)
    }
}

@objc
public protocol UANavigationDelegate: WKNavigationDelegate {
    @objc optional func closeWindow(_ animated: Bool)
}

private extension URL {
    var isAirshipCommand: Bool {
        return self.scheme == NativeBridge.airshipScheme
    }

    func isAllowed(scope: URLAllowListScope) -> Bool {
        return Airship.shared.urlAllowList.isAllowed(self, scope: scope)
    }
}

#endif
