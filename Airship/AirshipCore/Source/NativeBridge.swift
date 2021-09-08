/* Copyright Airship and Contributors */

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
    
    @objc
    public weak var nativeBridgeDelegate: NativeBridgeDelegate?
    
    @objc
    public weak var forwardNavigationDelegate: UANavigationDelegate?
    
    @objc
    public weak var javaScriptCommandDelegate: JavaScriptCommandDelegate?
    
    @objc
    public weak var nativeBridgeExtensionDelegate: NativeBridgeExtensionDelegate?
    
    private var actionHandler: NativeBridgeActionHandlerProtocol
    private var javaScriptEnvironmentFactoryBlock: () -> JavaScriptEnvironmentProtocol

    @objc(initWithActionHandler:javaScriptEnvironmentFactoryBlock:)
    public init(actionHandler: NativeBridgeActionHandlerProtocol, javaScriptEnvironmentFactoryBlock: @escaping () -> JavaScriptEnvironmentProtocol) {
        self.actionHandler = actionHandler
        self.javaScriptEnvironmentFactoryBlock = javaScriptEnvironmentFactoryBlock
        super.init()
    }

    @objc
    public convenience override init() {
        let actionHandler: NativeBridgeActionHandlerProtocol = NativeBridgeActionHandler.init()
        let javaScriptEnvironment: JavaScriptEnvironmentProtocol = JavaScriptEnvironment.init()
        self.init(actionHandler: actionHandler, javaScriptEnvironmentFactoryBlock: { return javaScriptEnvironment })
    }

    /**
     * Decide whether to allow or cancel a navigation.
     *
     * If a uairship:// URL, process it ourselves
     */
    @available(iOSApplicationExtension, unavailable)
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let navigationType = navigationAction.navigationType
        let request = navigationAction.request
        
        let originatingURL = webView.url
        
        /// Always handle uairship urls
        if (originatingURL != nil && self.isAllowedAirshipRequest(request: request as NSURLRequest, originatingURL: originatingURL!)) {
            if (navigationType == WKNavigationType.linkActivated || navigationType == WKNavigationType.other) {
                guard let url = request.url else {
                    return
                }
                let command = JavaScriptCommand.init(url:url)
                self.handleAirshipCommand(command: command , webView: webView)
            }
            decisionHandler(WKNavigationActionPolicy.cancel)
            return
        }
        
        /// If the forward delegate responds to the selector, let it decide
        self.forwardNavigationDelegate?.webView?(webView, decidePolicyFor: navigationAction, decisionHandler: { policyForThisURL in
            // Override any special link actions
            if (policyForThisURL == WKNavigationActionPolicy.allow && navigationType == WKNavigationType.linkActivated) {
                return
            }
            decisionHandler(policyForThisURL)
        })
        
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
     * Decide whether to allow or cancel a navigation after its response is known.
     */
    public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        guard (self.forwardNavigationDelegate?.webView?(webView, decidePolicyFor: navigationResponse, decisionHandler: decisionHandler)) != nil else {
            decisionHandler(.allow)
            return
        }
    }
    
    /**
     * Called when the navigation is complete.
     */
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.populateJavascriptEnvironmentIfAllowed(webview: webView)
        self.forwardNavigationDelegate?.webView?(webView, didFinish: navigation)
    }
    
    /**
     * Called when the web view begins to receive web content.
     */
    public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        self.forwardNavigationDelegate?.webView?(webView, didCommit: navigation)
    }
    
    /**
     * Called when the web view’s web content process is terminated.
     */
    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        self.forwardNavigationDelegate?.webViewWebContentProcessDidTerminate?(webView)
    }
    
    /**
     * Called when web content begins to load in a web view.
     */
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        self.forwardNavigationDelegate?.webView?(webView, didStartProvisionalNavigation: navigation)
    }
    
    /**
     * Called when a web view receives a server redirect.
     */
    public func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        self.forwardNavigationDelegate?.webView?(webView, didReceiveServerRedirectForProvisionalNavigation: navigation)
    }
    
    /**
     * Called when an error occurs during navigation.
     */
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.forwardNavigationDelegate?.webView?(webView, didFail: navigation, withError: error)
    }
    
    /**
     * Called when an error occurs while the web view is loading content.
     */
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        self.forwardNavigationDelegate?.webView?(webView, didFailProvisionalNavigation: navigation, withError: error)
    }
    
    
    /**
     * Called when the web view needs to respond to an authentication challenge.
     */
    public func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard self.forwardNavigationDelegate?.webView?(webView, didReceive: challenge, completionHandler: completionHandler) != nil else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
    }
    
    private func isAirshipRequest(request: NSURLRequest) -> Bool {
        return (request.url?.scheme == NativeBridge.UANativeBridgeUAirshipScheme)
    }

    private func isAllowed(url: URL) -> Bool {
        return Airship.shared.urlAllowList.isAllowed(url, scope: .javaScriptInterface)
    }
    
    private func isAllowedAirshipRequest(request: NSURLRequest, originatingURL: URL) -> Bool {
        /// uairship://command/[<arguments>][?<options>]
        return self.isAirshipRequest(request: request) && self.isAllowed(url: originatingURL)
    }

    private func handleAirshipCommand(command: JavaScriptCommand, webView: WKWebView) {
        /// Close
        if (command.name == NativeBridge.UANativeBridgeCloseCommand) {
            self.nativeBridgeDelegate?.close()
            return
        }
        
        /// Actions
        if (NativeBridgeActionHandler.isActionCommand(command: command)) {
            guard let metadata = self.nativeBridgeExtensionDelegate?.actionsMetadata?(for: command, webView: webView) else {
                return
            }
            
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
            let URLs = command.URL.query?.components(separatedBy: "&")
            guard URLs != nil else {
                return
            }
            
            for URLString in URLs! {
                let theURL = URL.init(string: URLString.removingPercentEncoding ?? "")
                guard (theURL != nil) else {
                    return
                }
                
                if (theURL!.scheme == NativeBridge.UANativeBridgeUAirshipScheme) {
                    let command = JavaScriptCommand.init(url: theURL!)
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
     *  - url The link's URL.
     *  - completionHandler  The completion handler to execute when openURL processing is complete.
     * -
     */
    @available(iOSApplicationExtension, unavailable)
    private func handle(_ url: URL, _ completionHandler: @escaping (Bool) -> Void ) {
        let forwardSchemes = ["itms-apps", "maps", "sms", "tel", "mailto"]
        let forwardHosts = ["maps.google.com", "www.youtube.com", "phobos.apple.com", "itunes.apple.com"]
        
        if (url.scheme == nil && url.host == nil) {
          completionHandler(false)
        }
        
        if (url.scheme != nil && forwardSchemes.contains(url.scheme!.lowercased()) ||
            url.host != nil && forwardHosts.contains(url.host!.lowercased())) {
            UIApplication.shared.open(url, options: [:]) { success in
                /// Its better to return YES here and no-op on these links instead of reporting an unhandled URL
                /// to avoid the message thinking it failed to load. The only time a NO will happen is on a simulator
                /// without access to the app store.
                completionHandler(true)
            }
        } else {
            completionHandler(false)
        }
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
