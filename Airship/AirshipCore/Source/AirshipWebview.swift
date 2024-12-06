/* Copyright Airship and Contributors */

#if !os(tvOS) && !os(watchOS)

import Foundation
import SwiftUI
import WebKit

/// Airship Webview
struct AirshipWebView: View {

    let info: ThomasViewInfo.WebView

    let constraints: ViewConstraints

    @State var isWebViewLoading: Bool = false
    @EnvironmentObject var thomasEnvironment: ThomasEnvironment
    @Environment(\.layoutState) var layoutState

    var body: some View {

        ZStack {
            WebViewView(
                url: self.info.properties.url,
                nativeBridgeExtension: self.thomasEnvironment.extensions?
                    .nativeBridgeExtension,
                isWebViewLoading: self.$isWebViewLoading,
                onRunActions: { name, value, _ in
                    return await thomasEnvironment.runAction(name, arguments: value, layoutState: layoutState)
                },
                onDismiss: {
                    thomasEnvironment.dismiss(layoutState: layoutState)
                }
            )
            .opacity(self.isWebViewLoading ? 0.0 : 1.0)

            if self.isWebViewLoading {
                AirshipProgressView()
            }
        }
        .constraints(constraints)
        .thomasCommon(self.info)
    }
}

/// Webview
struct WebViewView: UIViewRepresentable {
    typealias UIViewType = WKWebView

    let url: String
    let nativeBridgeExtension: NativeBridgeExtensionDelegate?
    @Binding var isWebViewLoading: Bool
    let onRunActions: @MainActor (String, ActionArguments, WKWebView) async -> ActionResult
    let onDismiss: () -> Void

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator.nativeBridge

        if #available(iOS 16.4, *) {
            webView.isInspectable = Airship.isFlying && Airship.config.airshipConfig.isWebViewInspectionEnabled
        }

        if let url = URL(string: self.url) {
            updateLoading(true)
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self, actionRunner: BlockNativeBridgeActionRunner(onRun: onRunActions))
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func updateLoading(_ isWebViewLoading: Bool) {
        DispatchQueue.main.async {
            self.isWebViewLoading = isWebViewLoading
        }
    }

    
    class Coordinator: NSObject, AirshipWKNavigationDelegate,
        JavaScriptCommandDelegate, NativeBridgeDelegate
    {
        private let parent: WebViewView
        private let challengeResolver: ChallengeResolver
        let nativeBridge: NativeBridge

        init(_ parent: WebViewView, actionRunner: NativeBridgeActionRunner, resolver: ChallengeResolver = .shared) {
            self.parent = parent
            self.nativeBridge = NativeBridge(actionRunner: actionRunner)
            self.challengeResolver = resolver
            
            super.init()
            
            self.nativeBridge.nativeBridgeExtensionDelegate =
                self.parent.nativeBridgeExtension
            self.nativeBridge.forwardNavigationDelegate = self
            self.nativeBridge.javaScriptCommandDelegate = self
            self.nativeBridge.nativeBridgeDelegate = self
        }

        func webView(
            _ webView: WKWebView,
            didFinish navigation: WKNavigation!
        ) {
            parent.updateLoading(false)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            parent.updateLoading(true)
            DispatchQueue.main.async {
                webView.reload()
            }
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            parent.updateLoading(true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                [weak webView] in
                webView?.reload()
            }
        }
        
        func webView(
            _ webView: WKWebView,
            respondTo challenge: URLAuthenticationChallenge)
        async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
            return await challengeResolver.resolve(challenge)
        }

        func performCommand(_ command: JavaScriptCommand, webView: WKWebView) -> Bool {
            return false
        }

        func close() {
            DispatchQueue.main.async {
                self.parent.onDismiss()
            }
        }
    }
}

#endif
