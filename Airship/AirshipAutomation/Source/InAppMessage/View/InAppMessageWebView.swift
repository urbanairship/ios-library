/* Copyright Airship and Contributors */

#if !os(tvOS)
import Foundation
import SwiftUI
import WebKit
#if canImport(AirshipCore)
import AirshipCore
#endif

struct InAppMessageWebView: View {
    let displayContent: InAppMessageDisplayContent.HTML

    @State var isWebViewLoading: Bool = false

    let accessibilityLabel: String?

    @EnvironmentObject var environment: InAppMessageEnvironment

    var body: some View {

        ZStack {
            WKWebViewRepresentable(
                url: self.displayContent.url,
                nativeBridgeExtension: self.environment.nativeBridgeExtension,
                isWebViewLoading: self.$isWebViewLoading,
                accessibilityLabel: accessibilityLabel,
                onRunActions: { name, value, _ in
                    return await environment.runAction(name, arguments: value)
                },
                onDismiss: {
                    environment.onUserDismissed()
                }
            )
            .addBackground(
                /// Add system background color by default - clear color will be parsed by the display content if it's set
                color: displayContent.backgroundColor?.color ?? Color(.systemBackground)
            )
            .zIndex(0)

            if self.isWebViewLoading {
                BeveledLoadingView()
                    .zIndex(1) /// Necessary to set z index for animation to work
                    .transition(.opacity)
            }
        }
    }
}

struct WKWebViewRepresentable: UIViewRepresentable {
    typealias UIViewType = WKWebView

    let url: String
    let nativeBridgeExtension: (any NativeBridgeExtensionDelegate)?
    @Binding var isWebViewLoading: Bool

    let accessibilityLabel: String?
    let onRunActions: @MainActor (String, ActionArguments, WKWebView) async -> ActionResult
    let onDismiss: () -> Void

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.navigationDelegate = context.coordinator.nativeBridge
        webView.isAccessibilityElement = true
        webView.accessibilityLabel = accessibilityLabel

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
            withAnimation {
                self.isWebViewLoading = isWebViewLoading
            }
        }
    }

    class Coordinator: NSObject, AirshipWKNavigationDelegate,
                       JavaScriptCommandDelegate, NativeBridgeDelegate
    {


        private let parent: WKWebViewRepresentable
        private let challengeResolver: ChallengeResolver
        let nativeBridge: NativeBridge

        init(_ parent: WKWebViewRepresentable, actionRunner: any NativeBridgeActionRunner, resolver: ChallengeResolver = .shared) {
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
            withError error: any Error
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

        nonisolated func close() {
            DispatchQueue.main.async {
                self.parent.onDismiss()
            }
        }
    }
}
#endif
