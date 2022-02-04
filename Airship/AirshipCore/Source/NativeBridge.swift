/* Copyright Airship and Contributors */

#if canImport(AirshipBasement)
import AirshipBasement
#endif

#if !os(tvOS)

import Foundation
import WebKit


/**
 * The native bridge will automatically load the Airship JavaScript environment into whitlelisted sites. The native
 * bridge must be assigned as the navigation delegate on a `WKWebView` in order to function.
 */
@objc(UANativeBridge)
public class NativeBridge : NSObject, WKNavigationDelegate {
    private static let UANativeBridgeUAirshipScheme = "uairship"
    private static let UANativeBridgeCloseCommand = "close"
    private static let UANativeBridgeSetNamedUserCommand = "named_user"
    private static let UANativeBridgeMultiCommand = "multi"
    
    private static let forwardSchemes = ["itms-apps", "maps", "sms", "tel", "mailto"]
    private static let forwardHosts = ["maps.google.com", "www.youtube.com", "phobos.apple.com", "itunes.apple.com"]
    

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
        let request = navigationAction.request
        
        let originatingURL = webView.url
        
        if (self.isAllowedAirshipRequest(request: request, originatingURL: originatingURL)) {
            // Always handle uairship urls
            if (navigationType == WKNavigationType.linkActivated || navigationType == WKNavigationType.other) {
                guard let url = request.url else {
                    return
                }
                let command = JavaScriptCommand(for: url)
                self.handleAirshipCommand(command: command , webView: webView)
            }
            decisionHandler(WKNavigationActionPolicy.cancel)
            return
        }
        
        if let forward = self.forwardNavigationDelegate?.webView as ((WKWebView, WKNavigationAction, @escaping (WKNavigationActionPolicy) -> Void) -> Void)? {
            
            forward(webView, navigationAction) { policyForThisURL in
                // Override any special link actions
                if (policyForThisURL == WKNavigationActionPolicy.allow && navigationType == WKNavigationType.linkActivated) {
                    self.handle(request.url) { success in
                        decisionHandler(success ? .cancel : .allow)
                    }
                    return
                }
                
                decisionHandler(policyForThisURL)
            }
            return
        }

        let handleLink: () -> Void = {
            /// If target frame is a new window navigation, have OS handle it
            guard navigationAction.request.url != nil else {
                return
            }
            if (navigationAction.targetFrame == nil) {
                UIApplication.shared.open(navigationAction.request.url!, options: [:], completionHandler: { success in
                    decisionHandler(success ? .cancel : .allow)
                })
                return
            }
            
            /// Default behavior
            decisionHandler(.allow)
        }
        
        /// Override any special link actions
        if (navigationType == WKNavigationType.linkActivated) {
            self.handle(request.url!) { success in
                if (success) {
                    decisionHandler(.cancel)
                    return
                }
                handleLink()
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
        self.populateJavascriptEnvironmentIfAllowed(webview: webView)
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
    
    private func isAirshipRequest(request: URLRequest) -> Bool {
        return (request.url?.scheme == NativeBridge.UANativeBridgeUAirshipScheme)
    }

    private func isAllowed(url: URL) -> Bool {
        return Airship.shared.urlAllowList.isAllowed(url, scope: .javaScriptInterface)
    }
    
    private func isAllowedAirshipRequest(request: URLRequest, originatingURL: URL?) -> Bool {
        guard let url = originatingURL else {
            return false
        }
        /// uairship://command/[<arguments>][?<options>]
        return self.isAirshipRequest(request: request) && self.isAllowed(url: url)
    }

    private func handleAirshipCommand(command: JavaScriptCommand, webView: WKWebView) {
        /// Close
        if (command.name == NativeBridge.UANativeBridgeCloseCommand) {
            self.nativeBridgeDelegate?.close()
            return
        }
        
        /// Actions
        if (NativeBridgeActionHandler.isActionCommand(command: command)) {
            let metadata = self.nativeBridgeExtensionDelegate?.actionsMetadata?(for: command, webView: webView)
            self.actionHandler.runActionsForCommand(command: command, metadata: metadata, completionHandler: { script in
                guard let script = script else {
                    return
                }
                webView.evaluateJavaScript(script, completionHandler: nil)
            })
            return
        }
        
        /// Set named user command
        if (command.name == NativeBridge.UANativeBridgeSetNamedUserCommand) {
            let idArgs: NSArray = command.options["id"] as! NSArray
            let argument = idArgs.firstObject as? String
            
            if argument == nil {
                AirshipLogger.error("Malformed Named User command")
            } else {
                let contact : ContactProtocol = Airship.contact
                if (argument!.count != 0) {
                    contact.identify(argument!)
                } else {
                    contact.reset()
                }
            }
        }
        
        /// Multi command
        if (command.name == NativeBridge.UANativeBridgeMultiCommand) {
            let URLs = command.url.query?.components(separatedBy: "&")
            guard URLs != nil else {
                return
            }
            
            for URLString in URLs! {
                let theURL = URL.init(string: URLString.removingPercentEncoding ?? "")
                guard (theURL != nil) else {
                    return
                }
                
                if (theURL!.scheme == NativeBridge.UANativeBridgeUAirshipScheme) {
                    let command = JavaScriptCommand(for: theURL!)
                    self.handleAirshipCommand(command: command, webView: webView)
                }
            }
            return
        }
        
        /// Local JavaScript command delegate
        var result = self.javaScriptCommandDelegate?.perform(command, webView: webView) ?? false
        if (result) {
            return
        }
        
        result = Airship.shared.javaScriptCommandDelegate?.perform(command, webView: webView) ?? false
        /// App defined JavaScript command delegate
        if (result) {
            return
        }
        
        AirshipLogger.debug(String(format: "Unhandled JavaScript command: %@", command))
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
    
    
    private func populateJavascriptEnvironmentIfAllowed(webview: WKWebView) {
        guard let url = webview.url else {
            return
        }
        if (!Airship.shared.urlAllowList.isAllowed(url, scope: .javaScriptInterface)) {
            /// Don't log in the special case of about:blank URLs
            if (url.absoluteString != "blank") {
                AirshipLogger.debug(String(format:"URL %@ is not allowed, not populating JS interface", url.absoluteString))
            }
            return
        }
        
        let js: JavaScriptEnvironmentProtocol = self.javaScriptEnvironmentFactoryBlock()
        self.nativeBridgeExtensionDelegate?.extendJavaScriptEnvironment?(js, webView: webview)
        webview.evaluateJavaScript(js.build(), completionHandler: nil)
    }
    
    private func closeWindow(_ animated: Bool) {
        self.forwardNavigationDelegate?.closeWindow?(animated)
    }
}

@objc
public protocol UANavigationDelegate: WKNavigationDelegate {
    @objc optional func closeWindow(_ animated: Bool)
}
    
#endif
