/* Copyright Airship and Contributors */

import Combine
import Foundation
public import SwiftUI

#if canImport(WebKit)
import WebKit
#endif

#if canImport(AirshipCore)
import AirshipCore
#endif

/// The Message Center message view.
@MainActor
public struct MessageCenterMessageView: View {

    @Environment(\.airshipMessageViewStyle)
    private var style

    /// The message's ID
    @StateObject
    private var viewModel: MessageCenterMessageViewModel

    /// The dismiss action callback
    private let dismissAction: (@MainActor @Sendable () -> Void)?

    /// Initializer.
    /// - Parameters:
    ///   - viewModel: The message center message view model.
    ///   - dismissAction: A dismiss action.
    public init(
        viewModel: MessageCenterMessageViewModel,
        dismissAction: (@MainActor @Sendable () -> Void)? = nil
    ) {
        _viewModel = .init(wrappedValue: viewModel)
        self.dismissAction = dismissAction
    }

    /// Initializer.
    /// - Parameters:
    ///   - messageID: The message ID.
    ///   - dismissAction: A dismiss action.
    public init(
        messageID: String,
        dismissAction: (@MainActor @Sendable () -> Void)? = nil
    ) {
        _viewModel = .init(wrappedValue: .init(messageID: messageID))
        self.dismissAction = dismissAction
    }

    @ViewBuilder
    /// The body of the view.
    public var body: some View {
        let configuration = MessageViewStyleConfiguration(
            viewModel: viewModel,
            dismissAction: dismissAction
        )

        style.makeBody(configuration: configuration)
    }
    
    enum DisplayPhase {
        case loading
        case error(any Error)
        case loaded
    }
}

extension View {
    /// Sets the style for the Message Center message view.
    /// - Parameters:
    ///     - style: The style to apply.
    public func messageCenterMessageViewStyle<S>(
        _ style: S
    ) -> some View where S: MessageViewStyle {
        self.environment(
            \.airshipMessageViewStyle,
             AnyMessageViewStyle(style: style)
        )
    }
}

/// The configuration for a Message Center message view.
public struct MessageViewStyleConfiguration: Sendable {
    /// The message view model.
    public let viewModel: MessageCenterMessageViewModel
    /// The dismiss action.
    public let dismissAction: (@MainActor @Sendable () -> Void)?
}

/// A protocol that defines the style for a Message Center message view.
public protocol MessageViewStyle: Sendable {
    associatedtype Body: View
    typealias Configuration = MessageViewStyleConfiguration
    @MainActor
    /// Creates the view body for the message view.
    /// - Parameters:
    ///   - configuration: The configuration for the message view.
    /// - Returns: The view body.
    func makeBody(configuration: Self.Configuration) -> Self.Body
}

extension MessageViewStyle where Self == DefaultMessageViewStyle {

    /// The default message view style.
    public static var defaultStyle: Self {
        return .init()
    }
}

/// The default style for a Message Center message view.
public struct DefaultMessageViewStyle: MessageViewStyle {
    @ViewBuilder
    @MainActor
    /// Creates the view body for the message view.
    /// - Parameters:
    ///   - configuration: The configuration for the message view.
    /// - Returns: The view body.
    public func makeBody(configuration: Configuration) -> some View {
        MessageCenterMessageContentView(
            viewModel: configuration.viewModel,
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
    @Environment(\.colorScheme)
    private var colorScheme

    @Environment(\.airshipMessageCenterTheme)
    private var theme

    @State
    private var messageLoadingPhase: MessageCenterMessageView.DisplayPhase = .loading
    
    @State
    private var opacity = 0.0
    
    @State
    private var contentType: MessageCenterMessage.ContentType? = nil

    @ObservedObject
    var viewModel: MessageCenterMessageViewModel
    let dismissAction: (@MainActor @Sendable () -> Void)?
    
    private var thomasLoadableLayout: LoadableLayout!
    
    init(
        viewModel: MessageCenterMessageViewModel,
        dismissAction: (@MainActor @Sendable () -> Void)?
    ) {
        self.viewModel = viewModel
        self.dismissAction = dismissAction
        self.contentType = viewModel.message?.contentType
        self.thomasLoadableLayout = LoadableLayout(request: self.makeRequest)
    }

    @MainActor
    private func makeRequest() async throws -> URLRequest {
        guard let message = await viewModel.fetchMessage(),
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
        guard let message = await viewModel.fetchMessage(),
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

        ZStack {
            if let backgroundColor {
                backgroundColor.ignoresSafeArea()
            }
            
            if self.contentType == nil {
                ProgressView().onAppear {
                    Task {
                        let message = await viewModel.fetchMessage()
                        self.contentType = message?.contentType
                    }
                }
            }
            
            messageContent()
                .opacity(self.opacity)
                .onReceive(Just(messageLoadingPhase)) { _ in
                    if case .loaded = self.messageLoadingPhase {
                        self.opacity = 1.0
                        if Airship.isFlying {
                            Task {
                                await viewModel.markRead()
                            }
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.5), value: self.opacity)
            
            if case .loading = self.messageLoadingPhase {
                ProgressView()
            } else if case .error(let error) = self.messageLoadingPhase {
                if let error = error as? MessageCenterMessageError,
                   error == .messageGone
                {
                    VStack {
                        Text(
                            "ua_mc_no_longer_available".messageCenterLocalizedString
                        )
                        .font(.headline)
                        .foregroundColor(.primary)
                    }
                } else {
                    VStack {
                        Text("ua_mc_failed_to_load".messageCenterLocalizedString)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Button("ua_retry_button".messageCenterLocalizedString) {
                            self.messageLoadingPhase = .loading
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func messageContent() -> some View {
        switch self.contentType {
        case .html, .plain:
            webBasedMessageView()
        case .native:
            thomasMessageView()
        case nil: EmptyView()
        }
    }
    
    @ViewBuilder
    private func webBasedMessageView() -> some View {
#if canImport(WebKit)
        MessageCenterWebView(
            phase: self.$messageLoadingPhase,
            nativeBridgeExtension: {
                try await makeExtensionDelegate(messageID: viewModel.messageID)
            },
            request: {
                try await makeRequest()
            },
            dismiss: {
                await MainActor.run {
                    dismiss()
                }
            }
        )
#else
        Text("ua_mc_failed_to_load".messageCenterLocalizedString)
            .font(.headline)
            .foregroundColor(.primary)
#endif
    }
    
    @ViewBuilder
    private func thomasMessageView() -> some View {
        if let analytics = viewModel.makeAnalytics(onDismiss: { [action = dismissAction] in action?() } ) {
            MessageCenterThomasView(
                phase: self.$messageLoadingPhase,
                layout: self.thomasLoadableLayout,
                analytics: analytics,
                timer: viewModel.timer
            ).also { [weak viewModel] view in
                viewModel?.backButtonCallbackDelegate = view.backButtonDelegate
            }
        } else {
            EmptyView()
        }
    }

    private func dismiss() {
        self.dismissAction?()
    }
}

