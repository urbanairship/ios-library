import Combine
import Foundation
import SwiftUI

#if canImport(WebKit)
import WebKit
#endif

#if canImport(AirshipCore)
import AirshipCore
#endif

#if canImport(WebKit)
struct MessageCenterWebView: AirshipNativeViewRepresentable {

#if os(macOS)
    typealias NSViewType = WKWebView
    func makeNSView(context: Context) -> WKWebView {
        return makeWebView(context: context)
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        updateView(nsView, context: context)
    }
#else
    typealias UIViewType = WKWebView

    func makeUIView(context: Context) -> WKWebView {
        return makeWebView(context: context)
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        updateView(uiView, context: context)
    }
#endif

    @Binding
    var phase: MessageCenterMessageView.DisplayPhase
    let nativeBridgeExtension:
    (() async throws -> MessageCenterNativeBridgeExtension)?

    let request: () async throws -> URLRequest

    let dismiss: () async -> Void

    @State
    private var isWebViewLoading: Bool = false

    private var isLoading: Bool {
        guard case .loading = self.phase else {
            return false
        }
        return true
    }

    func makeWebView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()

#if !os(macOS)
        configuration.allowsInlineMediaPlayback = true
        configuration.dataDetectorTypes = .all
#endif

        let webView = WKWebView(
            frame: CGRect.zero,
            configuration: configuration
        )
        webView.allowsLinkPreview = false
        webView.navigationDelegate = context.coordinator.nativeBridge

        if #available(iOS 16.4, *) {
            webView.isInspectable = Airship.isFlying && Airship.config.airshipConfig.isWebViewInspectionEnabled
        }

        return webView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func updateView(_ uiView: WKWebView, context: Context) {
        Task {
            await checkLoad(
                webView: uiView,
                coordinator: context.coordinator
            )
        }
    }

    @MainActor
    func checkLoad(webView: WKWebView, coordinator: Coordinator) async {
        if isLoading, !isWebViewLoading {
            await self.load(webView: webView, coordinator: coordinator)
        }
    }

    @MainActor
    func load(webView: WKWebView, coordinator: Coordinator) async {
        self.phase = .loading

        do {
            let delegate = try await self.nativeBridgeExtension?()
            coordinator.nativeBridgeExtensionDelegate = delegate

            let request = try await self.request()
            _ = webView.load(request)
            self.isWebViewLoading = true
        } catch {
            self.phase = .error(error)
        }
    }

    @MainActor
    private func pageFinished(error: (any Error)? = nil) async {
        self.isWebViewLoading = false

        if let error = error {
            self.phase = .error(error)
        } else {
            self.phase = .loaded
        }
    }

    class Coordinator: NSObject, AirshipWKNavigationDelegate,
                       JavaScriptCommandDelegate,
                       NativeBridgeDelegate
    {


        private let parent: MessageCenterWebView
        private let challengeResolver: ChallengeResolver
        let nativeBridge: NativeBridge
        var nativeBridgeExtensionDelegate: (any NativeBridgeExtensionDelegate)? {
            didSet {
                self.nativeBridge.nativeBridgeExtensionDelegate = self.nativeBridgeExtensionDelegate
            }
        }

        init(_ parent: MessageCenterWebView, resolver: ChallengeResolver = .shared) {
            self.parent = parent
            self.nativeBridge = NativeBridge()
            self.challengeResolver = resolver
            super.init()
            self.nativeBridge.forwardNavigationDelegate = self
            self.nativeBridge.javaScriptCommandDelegate = self
            self.nativeBridge.nativeBridgeDelegate = self
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!)
        {
            Task { @MainActor in
                await parent.pageFinished()
            }
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            Task { @MainActor in
                await parent.load(webView: webView, coordinator: self)
            }
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: any Error
        ) {
            Task { @MainActor in
                await parent.pageFinished(error: error)
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
            Task { @MainActor in
                await parent.dismiss()
            }
        }
    }
}
#endif
