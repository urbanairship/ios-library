/* Copyright Airship and Contributors */

import Foundation
public import SwiftUI

#if canImport(WebKit)
import WebKit
#endif

#if canImport(AirshipCore)
import AirshipCore
#endif

/// A view that loads and displays the content of a Message Center message.
///
/// Unlike ``MessageCenterMessageView``, this view renders only the message
/// content itself — the web or native (Scenes) body. It does **not** display a
/// loading indicator, error UI, retry button, or fade-in animation, and it does
/// not mark the message as read. Instead it reports its loading state through
/// the `phase` binding so the host can present its own loading and error UI.
@MainActor
public struct MessageCenterMessageContentView: View {

    @ObservedObject
    private var viewModel: MessageCenterMessageViewModel

    @Binding
    private var phase: MessageCenterMessageContentPhase

    private let dismissAction: (@MainActor @Sendable () -> Void)?

    @State
    private var contentType: MessageCenterMessage.ContentType

    /// Initializer.
    /// - Parameters:
    ///   - viewModel: The message center message view model.
    ///   - phase: A binding to the content's loading phase. Set it to
    ///     ``MessageCenterMessageContentPhase/loading`` to (re)load the content.
    ///   - dismissAction: An optional dismiss action invoked when the message
    ///     content requests dismissal (e.g. a web message calling `close()`).
    public init(
        viewModel: MessageCenterMessageViewModel,
        phase: Binding<MessageCenterMessageContentPhase>,
        dismissAction: (@MainActor @Sendable () -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self._phase = phase
        self.dismissAction = dismissAction
        self._contentType = State(
            initialValue: viewModel.message?.contentType ?? .unknown(nil)
        )
    }

    public var body: some View {
        messageContent()
            .task(id: self.phase.isLoading) {
                guard self.phase.isLoading else { return }
                do {
                    let message = try await viewModel.fetchMessageThrowing()
                    self.contentType = message.contentType
                } catch {
                    self.phase = .error(.from(error))
                }
            }
    }

    @MainActor
    private static func makeRequest(
        viewModel: MessageCenterMessageViewModel
    ) async throws -> URLRequest {
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

    @ViewBuilder
    private func messageContent() -> some View {
        switch self.contentType {
        case .html, .plain, .unknown:
            webBasedMessageView()
        case .native:
            thomasMessageView()
        }
    }

    @ViewBuilder
    private func webBasedMessageView() -> some View {
#if canImport(WebKit)
        MessageCenterWebView(
            phase: self.$phase,
            nativeBridgeExtension: {
                try await makeExtensionDelegate(messageID: viewModel.messageID)
            },
            request: {
                try await Self.makeRequest(viewModel: self.viewModel)
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
        if let displayListener = viewModel.makeAnalytics(onDismiss: { [action = dismissAction] in action?() }) {
            MessageCenterThomasView(
                phase: self.$phase,
                layoutRequest: { try await Self.makeRequest(viewModel: viewModel) },
                displayListener: displayListener,
                dismissHandle: self.viewModel.thomasDismissHandle,
                stateStorage: { viewModel.getOrCreateNativeStateStorage() }
            )
        } else {
            EmptyView()
        }
    }

    private func dismiss() {
        self.dismissAction?()
    }
}

extension MessageCenterMessageContentPhase {
    /// Whether the phase is ``MessageCenterMessageContentPhase/loading``.
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    /// Whether the phase is ``MessageCenterMessageContentPhase/loaded``.
    var isLoaded: Bool {
        if case .loaded = self { return true }
        return false
    }
}
