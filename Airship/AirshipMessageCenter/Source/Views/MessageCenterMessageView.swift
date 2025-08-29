/* Copyright Urban Airship and Contributors */

import Combine
import Foundation
public import SwiftUI

#if canImport(WebKit)
import WebKit
#endif

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

    /// The dismiss action callback
    private let dismissAction: (@MainActor @Sendable () -> Void)?

    /// Default constructor
    /// - Parameters:
    ///     - messageID: The message ID to load
    ///     - title: The title. If not set the title will be loaded from the message.
    ///     - dismissAction: Optional action to dismiss the message view message.
    public init(
        messageID: String,
        title: String?,
        dismissAction: (@MainActor @Sendable () -> Void)? = nil
    ) {
        self.messageID = messageID
        self.title = title
        self.dismissAction = dismissAction
    }

    @ViewBuilder
    public var body: some View {

        let configuration = MessageViewStyleConfiguration(
            messageID: messageID,
            title: title,
            dismissAction: dismissAction
        )

        style.makeBody(configuration: configuration)
    }
}

extension View {
    /// Sets the Message Center message style
    /// - Parameters:
    ///     - style: The style
    public func messageCenterMessageViewStyle<S>(
        _ style: S
    ) -> some View where S: MessageViewStyle {
        self.environment(
            \.airshipMessageViewStyle,
             AnyMessageViewStyle(style: style)
        )
    }
}

/// Message view style configuration
public struct MessageViewStyleConfiguration: Sendable {
    public let messageID: String
    public let title: String?
    public let dismissAction: (@MainActor @Sendable () -> Void)?
}

public protocol MessageViewStyle: Sendable {
    associatedtype Body: View
    typealias Configuration = MessageViewStyleConfiguration
    @MainActor
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
    @MainActor
    public func makeBody(configuration: Configuration) -> some View {
        MessageCenterMessageContentView(
            messageID: configuration.messageID,
            title: configuration.title,
            dismissAction: configuration.dismissAction
        )
    }
}

struct AnyMessageViewStyle: MessageViewStyle {
    @ViewBuilder
    private let _makeBody: @MainActor @Sendable (Configuration) -> AnyView

    init<S: MessageViewStyle>(style: S) {
        _makeBody = { @MainActor configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

#if canImport(WebKit)
struct MessageCenterWebView: UIViewRepresentable {
    typealias UIViewType = WKWebView

    enum Phase {
        case loading
        case error(any Error)
        case loaded
    }

    @Binding
    var phase: Phase
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

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.dataDetectorTypes = .all

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

struct MessageViewStyleKey: EnvironmentKey {
    static let defaultValue = AnyMessageViewStyle(style: .defaultStyle)
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

    @Environment(\.colorScheme)
    private var colorScheme

    @Environment(\.airshipMessageCenterTheme)
    private var theme

    @Environment(\.messageCenterDetectedAppearance)
    private var detectedAppearance

#if canImport(WebKit)

    @State
    private var webViewPhase: MessageCenterWebView.Phase = .loading
#endif

    @State
    private var message: MessageCenterMessage? = nil

    @State
    private var opacity = 0.0

    let messageID: String
    let title: String?
    let dismissAction: (() -> Void)?

    /// Prioritizes theme values -> inherited appearance -> defaults
    private var effectiveColors: MessageCenterEffectiveColors {
        MessageCenterEffectiveColors(
            detectedAppearance: detectedAppearance,
            theme: theme,
            colorScheme: colorScheme
        )
    }

    @MainActor
    func getMessage(_ messageID: String) async -> MessageCenterMessage? {
        if let message = message {
            return message
        }
        var message = await Airship.messageCenter.inbox.message(
            forID: messageID
        )

        if message == nil {
            await Airship.messageCenter.inbox.refreshMessages()
            message = await Airship.messageCenter.inbox.message(
                forID: messageID
            )
        }

        self.message = message
        return message
    }

    @MainActor
    private func makeRequest(forMessageID messageID: String) async throws
    -> URLRequest
    {
        guard let message = await getMessage(messageID),
              let user = await Airship.messageCenter.inbox.user
        else {
            throw AirshipErrors.error("")
        }

        var request = URLRequest(url: message.bodyURL)
        request.setValue(
            user.basicAuthString,
            forHTTPHeaderField: "Authorization"
        )
        request.timeoutInterval = 120
        return request
    }

#if canImport(WebKit)
    @MainActor
    private func makeExtensionDelegate(
        messageID: String
    ) async throws -> MessageCenterNativeBridgeExtension {
        guard let message = await getMessage(messageID),
              let user = await Airship.messageCenter.inbox.user
        else {
            throw AirshipErrors.error("")
        }

        return MessageCenterNativeBridgeExtension(
            message: message,
            user: user
        )
    }
#endif

    var body: some View {
        let backgroundColor = self.colorScheme.airshipResolveColor(
            light: self.theme.messageViewBackgroundColor,
            dark: self.theme.messageViewBackgroundColorDark
        )

        let containerColor = effectiveColors.navigationBarBackgroundColor ?? self.colorScheme.airshipResolveColor(
            light: self.theme.messageViewContainerBackgroundColor,
            dark: self.theme.messageViewContainerBackgroundColorDark
        )

        ZStack {
            if let backgroundColor {
                backgroundColor.ignoresSafeArea()
            }

#if canImport(WebKit)

            MessageCenterWebView(
                phase: self.$webViewPhase,
                nativeBridgeExtension: {
                    try await makeExtensionDelegate(messageID: messageID)
                },
                request: {
                    try await makeRequest(forMessageID: messageID)
                },
                dismiss: {
                    await MainActor.run {
                        dismiss()
                    }
                }
            )
            .opacity(self.opacity)
            .onReceive(Just(webViewPhase)) { _ in
                if case .loaded = self.webViewPhase {
                    self.opacity = 1.0

                    if Airship.isFlying {
                        Task {
                            let message = await Airship.messageCenter.inbox
                                .message(
                                    forID: messageID
                                )
                            if let message = message {
                                await Airship.messageCenter.inbox.markRead(
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
                        Text("ua_mc_no_longer_available".messageCenterLocalizedString)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                } else {
                    VStack {
                        Text("ua_mc_failed_to_load".messageCenterLocalizedString)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Button("ua_retry_button".messageCenterLocalizedString) {
                            self.webViewPhase = .loading
                        }
                    }
                }
            }
#else
            Text("ua_mc_failed_to_load".messageCenterLocalizedString)
                .font(.headline)
                .foregroundColor(.primary)
#endif
        }
        .applyUIKitNavigationAppearance()
        .navigationBarBackButtonHidden(true) // Hide the default back button
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarLeading) {
                backButton
            }

            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Delete button
                deleteButton
            }

            ToolbarItemGroup(placement: .principal) {
                // Custom title with detected color
                Text(title ?? self.message?.title ?? "")
                    .foregroundColor(effectiveColors.navigationTitleColor ?? Color.primary)
                    .airshipApplyIf(detectedAppearance?.navigationTitleFont != nil) { text in
                        text.font(detectedAppearance!.navigationTitleFont)
                    }

            }
        }
        .airshipApplyIf(containerColor != nil) { view in
            if #available(iOS 16.0, *) {
                view.toolbarBackground(containerColor!, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
            } else {
                view.background(containerColor!)
            }
        }
    }

    @ViewBuilder
    private var deleteButton: some View {
        if theme.hideDeleteButton != true {
            Button("ua_delete_message".messageCenterLocalizedString) {
                Task {
                    await Airship.messageCenter.inbox.delete(
                        messageIDs: [self.messageID]
                    )
                }
                dismiss()
            }.foregroundColor(effectiveColors.deleteButtonColor)
        }
    }

    @ViewBuilder
    private var backButton: some View {
        Button(action: {
            self.dismiss()
        }) {
            Image(systemName: "chevron.backward")
                .scaleEffect(0.68)
                .font(Font.title.weight(.medium))
                .foregroundColor(effectiveColors.backButtonColor)
        }
    }

    private func dismiss() {
        if let dismissAction = self.dismissAction {
            dismissAction()
        } else {
            presentationMode.wrappedValue.dismiss()
        }
    }
}

