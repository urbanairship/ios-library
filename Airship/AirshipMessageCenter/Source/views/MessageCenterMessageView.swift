/* Copyright Urban Airship and Contributors */

import Combine
import Foundation
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

enum MessageCenterMessageError: Error {
    case messageGone
    case failedToFetchMessage
}

/// The Message Center message view
public struct MessageCenterMessageView: View {

    @Environment(\.airshipMessageViewStyle)
    private var style

    /// The message's ID
    private let messageID: String

    /// The message's title
    private let title: String?

    /// Default constructor
    /// - Parameters:
    ///     - messageID: The message ID to load
    ///     - title: The title. If not set the title will be loaded from the message.
    public init(messageID: String, title: String?) {
        self.messageID = messageID
        self.title = title
    }

    @ViewBuilder
    public var body: some View {

        let configuration = MessageViewStyleConfiguration(
            messageID: messageID,
            title: title
        )

        style.makeBody(configuration: configuration)
    }
}

extension View {

    /// Sets the message style
    /// - Parameters:
    ///     - style: The style
    public func setMessageCenterMessageViewStyle<S>(
        _ style: S
    ) -> some View where S: MessageViewStyle {
        self.environment(
            \.airshipMessageViewStyle,
            AnyMessageViewStyle(style: style)
        )
    }
}

/// Message view style configuration
public struct MessageViewStyleConfiguration {
    public let messageID: String
    public let title: String?
}

public protocol MessageViewStyle {
    associatedtype Body: View
    typealias Configuration = MessageViewStyleConfiguration
    func makeBody(configuration: Self.Configuration) -> Self.Body
}

extension MessageViewStyle where Self == DefaultMessageViewStyle {

    /// Default style
    public static var defaultStyle: Self {
        return .init()
    }
}

/// The default message view view style
public struct DefaultMessageViewStyle: MessageViewStyle {
    @ViewBuilder
    public func makeBody(configuration: Configuration) -> some View {
        MessageCenterMessageContentView(
            messageID: configuration.messageID,
            title: configuration.title
        )
    }
}

struct AnyMessageViewStyle: MessageViewStyle {
    @ViewBuilder
    private var _makeBody: (Configuration) -> AnyView

    init<S: MessageViewStyle>(style: S) {
        _makeBody = { configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

struct AirshipWebView: UIViewRepresentable {
    typealias UIViewType = WKWebView

    enum Phase {
        case loading
        case error(Error)
        case loaded
    }

    @Binding
    var phase: Phase
    let nativeBridgeExtension:
        (() async throws -> NativeBridgeExtensionDelegate)?

    let request: () async throws -> URLRequest

    let dismiss: () async -> Void

    @State
    private var isLoading: Bool = false

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        let webView = WKWebView(
            frame: CGRect.zero,
            configuration: configuration
        )
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
            coordinator.nativeBridgeExtensionDelegate = delegate

            let request = try await self.request()
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

    class Coordinator: NSObject, UANavigationDelegate,
        JavaScriptCommandDelegate,
        NativeBridgeDelegate
    {
        private let parent: AirshipWebView
        let nativeBridge: NativeBridge
        var nativeBridgeExtensionDelegate: NativeBridgeExtensionDelegate? {
            didSet {
                self.nativeBridge.nativeBridgeExtensionDelegate = self.nativeBridgeExtensionDelegate
            }
        }

        init(_ parent: AirshipWebView) {
            self.parent = parent
            self.nativeBridge = NativeBridge()
            super.init()
            self.nativeBridge.forwardNavigationDelegate = self
            self.nativeBridge.javaScriptCommandDelegate = self
            self.nativeBridge.nativeBridgeDelegate = self
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!)
        {
            Task {
                await parent.pageFinished()
            }
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            Task {
                await parent.load(webView: webView, coordinator: self)
            }
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            Task {
                await parent.pageFinished(error: error)
            }
        }

        func perform(
            _ command: JavaScriptCommand,
            webView: WKWebView
        ) -> Bool {
            return false
        }

        func close() {
            Task {
                await parent.dismiss()
            }
        }
    }
}

struct MessageViewStyleKey: EnvironmentKey {
    static var defaultValue = AnyMessageViewStyle(style: .defaultStyle)
}

extension EnvironmentValues {
    var airshipMessageViewStyle: AnyMessageViewStyle {
        get { self[MessageViewStyleKey.self] }
        set { self[MessageViewStyleKey.self] = newValue }
    }
}

private struct MessageCenterMessageContentView: View {

    @Environment(\.presentationMode)
    private var presentationMode: Binding<PresentationMode>

    @State
    private var webViewPhase: AirshipWebView.Phase = .loading

    @State
    private var message: MessageCenterMessage? = nil

    @State
    private var opacity = 0.0

    let messageID: String
    let title: String?

    private var isLoading: Bool {
        guard case .loading = self.webViewPhase else {
            return false
        }
        return true
    }

    private var isLoaded: Bool {
        guard case .loaded = self.webViewPhase else {
            return false
        }
        return true
    }

    @MainActor
    func getMessage(_ messageID: String) async -> MessageCenterMessage? {
        if let message = message {
            return message
        }
        let message = await MessageCenter.shared.inbox.message(
            forID: messageID
        )
        self.message = message
        return message
    }

    private func makeRequest(forMessageID messageID: String) async throws
        -> URLRequest
    {
        guard let message = await getMessage(messageID),
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

    private func makeExtensionDelegate(messageID: String) async throws
        -> NativeBridgeExtensionDelegate
    {
        guard let message = await getMessage(messageID),
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
                    try await makeExtensionDelegate(messageID: messageID)
                },
                request: {
                    try await makeRequest(forMessageID: messageID)
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
                            let message = await MessageCenter.shared.inbox
                                .message(
                                    forID: messageID
                                )
                            if let message = message {
                                await MessageCenter.shared.inbox.markRead(
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
                        Text("ua_mc_no_longer_available".localized)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                } else {
                    VStack {
                        Text("ua_mc_failed_to_load".localized)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Button("ua_retry_button".localized) {
                            self.webViewPhase = .loading
                        }
                    }
                }
            }
        }
        .navigationTitle(title ?? self.message?.title ?? "")
    }
}
