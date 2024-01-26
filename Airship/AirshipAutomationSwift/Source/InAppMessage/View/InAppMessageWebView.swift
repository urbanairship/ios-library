/* Copyright Airship and Contributors */

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
                accessibilityLabel: accessibilityLabel
            ) {
                environment.onDismiss?()
            }.zIndex(0)

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
    let nativeBridgeExtension: NativeBridgeExtensionDelegate?
    @Binding var isWebViewLoading: Bool
    let accessibilityLabel: String?

    let onDismiss: () -> Void

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator.nativeBridge

        webView.isAccessibilityElement = true
        webView.accessibilityLabel = accessibilityLabel
        if let url = URL(string: self.url) {
            updateLoading(true)
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func updateLoading(_ isWebViewLoading: Bool) {
        DispatchQueue.main.async {
            withAnimation {
                self.isWebViewLoading = isWebViewLoading
            }
        }
    }

    class Coordinator: NSObject, UANavigationDelegate,
                       JavaScriptCommandDelegate, NativeBridgeDelegate
    {


        private let parent: WKWebViewRepresentable
        let nativeBridge: NativeBridge

        init(_ parent: WKWebViewRepresentable) {
            self.parent = parent
            self.nativeBridge = NativeBridge()
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
