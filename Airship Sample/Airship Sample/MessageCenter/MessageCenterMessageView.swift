/* Copyright Urban Airship and Contributors */

import Foundation
import UIKit
import AirshipMessageCenter
import SwiftUI
import Combine
import AirshipCore


enum MessageCenterMessageError: Error {
    case messageGone
    case failedToFetchMessage
}

struct MessageView: View {
    let messageID: String
    let title: String?

    @Environment(\.presentationMode)
    private var presentationMode: Binding<PresentationMode>

    @State
    private var webViewPhase: AirshipWebView.Phase = .loading

    @State
    private var message: MessageCenterMessage? = nil

    @State
    private var opacity = 0.0

    private var isLoading: Bool {
        if case .loading = self.webViewPhase {
            return true
        } else {
            return false
        }
    }

    private var isLoaded: Bool {
        if case .loaded = self.webViewPhase {
            return true
        } else {
            return false
        }
    }


    @MainActor
    func getMessage() async -> MessageCenterMessage? {
        if let message = message {
            return message
        }
        let message = await MessageCenter.shared.inbox.message(
            forID: self.messageID
        )
        self.message = message
        return message
    }

    private func makeRequest() async throws -> URLRequest {
        guard let message = await getMessage(),
              let user = await MessageCenter.shared.inbox.user
        else {
            throw AirshipErrors.error("")
        }

        var request = URLRequest(url: message.bodyURL)
        request.setValue(
            user.basicAuthString,
            forHTTPHeaderField: "Authorization"
        )
        request.timeoutInterval = 60
        return request
    }

    private func makeExtensionDelegate() async throws -> NativeBridgeExtensionDelegate {
        guard let message = await getMessage(),
              let user = await MessageCenter.shared.inbox.user
        else {
            throw AirshipErrors.error("")
        }

        return MessageCenterNativeBridgeExtension(
            message: message,
            user: user
        )
    }


    var body: some View {
        ZStack {
            AirshipWebView(
                phase: self.$webViewPhase,
                nativeBridgeExtension: {
                    try await makeExtensionDelegate()
                },
                request: {
                    try await makeRequest()
                },
                dismiss: {
                    await MainActor.run {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            )
            .opacity(self.opacity)
            .onReceive(Just(webViewPhase)) { _ in
                if case .loaded = self.webViewPhase {
                    self.opacity = 1.0

                    if Airship.isFlying {
                        Task {
                            let message = await MessageCenter.shared.inbox.message(
                                forID: self.messageID
                            )
                            if let message = message {
                                await
                                MessageCenter.shared.inbox.markRead(
                                    messages: [message]
                                )
                            }

                        }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.5), value: self.opacity)

            if case .loading = self.webViewPhase {
                ProgressView()
            } else if case .error(let error) = self.webViewPhase {
                if let error = error as? MessageCenterMessageError,
                   error == .messageGone
                {
                    VStack {
                        Text("Message is no longer available")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                } else {
                    VStack {
                        Text("Failed to load the message")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Button("Retry") {
                            self.webViewPhase = .loading
                        }
                    }
                }
            }
        }
        .navigationTitle(title ?? self.message?.title ?? "Message")
    }
}


struct AirshipWebView : UIViewRepresentable  {
    typealias UIViewType = WKWebView

    enum Phase {
        case loading
        case error(Error)
        case loaded
    }

    @Binding
    var phase: Phase
    let nativeBridgeExtension: (() async throws -> NativeBridgeExtensionDelegate)?

    let request: () async throws -> URLRequest

    let dismiss: () async -> Void

    @State
    private var isLoading: Bool = false

    func makeUIView(context: Context) -> WKWebView  {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator.nativeBridge
        return webView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        Task {
            await checkLoad(
                webView: uiView,
                coordinator: context.coordinator
            )
        }
    }

    @MainActor
    func checkLoad(webView: WKWebView, coordinator: Coordinator) async {
        if case .loading = phase, !isLoading {
            await self.load(webView: webView, coordinator: coordinator)
        }
    }

    @MainActor
    func load(webView: WKWebView, coordinator: Coordinator) async {
        self.phase = .loading

        do {
            let delegate = try await self.nativeBridgeExtension?()
            let request = try await self.request()

            coordinator.nativeBridge.nativeBridgeExtensionDelegate = delegate
            _ = webView.load(request)
            self.isLoading = true
        } catch {
            self.phase = .error(error)
        }
    }


    @MainActor
    private func pageFinished(error: Error? = nil) async {
        self.isLoading = false

        if let error = error {
            self.phase = .error(error)
        } else {
            self.phase = .loaded
        }
    }

    class Coordinator : NSObject, UANavigationDelegate, JavaScriptCommandDelegate, NativeBridgeDelegate {
        private let parent: AirshipWebView
        let nativeBridge: NativeBridge

        init(_ parent: AirshipWebView) {
            self.parent = parent
            self.nativeBridge = NativeBridge()
            super.init()
            self.nativeBridge.forwardNavigationDelegate = self
            self.nativeBridge.javaScriptCommandDelegate = self
            self.nativeBridge.nativeBridgeDelegate = self
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task {
                await parent.pageFinished()
            }
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            Task {
                await parent.load(webView: webView, coordinator: self)
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Task {
                await parent.pageFinished(error: error)
            }
        }

        func perform(_ command: JavaScriptCommand,
                     webView: WKWebView) -> Bool {
            return false
        }

        func close() {
            Task {
                await parent.dismiss()
            }
        }
    }
}

