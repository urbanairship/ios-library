/* Copyright Airship and Contributors */

#if !os(tvOS) && !os(watchOS)

@_spi(AirshipInternal) import AirshipSceneRenderer
@_spi(AirshipInternal) import AirshipBasement
import Foundation
import SwiftUI
import WebKit
@_spi(AirshipInternal) import AirshipCore

/// Default Airship web view: a `NativeBridge`-backed `WKWebView`. Built by the host delegate so
/// the renderer never needs to know about WebKit or the native bridge.
struct AirshipThomasWebView: View {

    let url: String
    let layoutContext: @MainActor () -> ThomasLayoutContext
    let actionRunner: (any ThomasActionRunner)?
    let nativeBridgeExtension: (any NativeBridgeExtensionDelegate)?
    @Binding var isLoading: Bool
    let onClose: @MainActor () -> Void

    var body: some View {
        WebViewRepresentable(
            url: url,
            layoutContext: layoutContext,
            actionRunner: actionRunner,
            nativeBridgeExtension: nativeBridgeExtension,
            isLoading: $isLoading,
            onClose: onClose
        )
    }
}

private struct WebViewRepresentable: AirshipNativeViewRepresentable {

#if os(macOS)
    typealias NSViewType = WKWebView
#else
    typealias UIViewType = WKWebView
#endif

    let url: String
    let layoutContext: @MainActor () -> ThomasLayoutContext
    let actionRunner: (any ThomasActionRunner)?
    let nativeBridgeExtension: (any NativeBridgeExtensionDelegate)?
    @Binding var isLoading: Bool
    let onClose: @MainActor () -> Void

#if os(macOS)
    func makeNSView(context: Context) -> WKWebView {
        return makeWebView(context: context)
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        coordinator.teardown()
    }
#else
    func makeUIView(context: Context) -> WKWebView {
        return makeWebView(context: context)
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.teardown()
    }
#endif

    private func makeWebView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator.nativeBridge
        context.coordinator.configure(webView: webView)

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
        let bridgeActionRunner = BlockNativeBridgeActionRunner { [actionRunner, layoutContext] name, arguments, _ in
            if let actionRunner {
                return await actionRunner.run(
                    actionName: name,
                    arguments: arguments,
                    layoutContext: layoutContext()
                )
            }
            return await ActionRunner.run(actionName: name, arguments: arguments)
        }
        return Coordinator(self, actionRunner: bridgeActionRunner)
    }

    func updateLoading(_ loading: Bool) {
        DispatchQueue.main.async {
            self.isLoading = loading
        }
    }

    class Coordinator: NSObject, AirshipWKNavigationDelegate,
                       JavaScriptCommandDelegate, NativeBridgeDelegate
    {
        private let parent: WebViewRepresentable
        private let challengeResolver: ChallengeResolver
        private weak var webView: WKWebView?
        let nativeBridge: NativeBridge

        init(_ parent: WebViewRepresentable, actionRunner: any NativeBridgeActionRunner, resolver: ChallengeResolver = .shared) {
            self.parent = parent
            self.nativeBridge = NativeBridge(actionRunner: actionRunner)
            self.challengeResolver = resolver

            super.init()
            AirshipLogger.trace("AirshipThomasWebView Coordinator init")
            self.nativeBridge.nativeBridgeExtensionDelegate = parent.nativeBridgeExtension
            self.nativeBridge.forwardNavigationDelegate = self
            self.nativeBridge.javaScriptCommandDelegate = self
            self.nativeBridge.nativeBridgeDelegate = self
        }

        deinit {
            AirshipLogger.trace("AirshipThomasWebView Coordinator deinit")
        }

        func configure(webView: WKWebView) {
            self.webView = webView
        }

        @MainActor
        func teardown() {
            self.webView?.stopLoading()
            self.webView?.navigationDelegate = nil
            self.webView?.pauseAllMediaPlayback()
#if !os(macOS)
            if #unavailable(iOS 26.3) {
                if self.webView?.superview != nil {
                    self.webView?.removeFromSuperview()
                }
            }
#endif
            self.webView = nil
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak webView] in
                webView?.reload()
            }
        }

        func webView(
            _ webView: WKWebView,
            respondTo challenge: URLAuthenticationChallenge
        ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
            return await challengeResolver.resolve(challenge)
        }

        func performCommand(_ command: JavaScriptCommand, webView: WKWebView) -> Bool {
            return false
        }

        nonisolated func close() {
            DispatchQueue.main.async {
                self.parent.onClose()
            }
        }
    }
}

#endif
