/* Copyright Airship and Contributors */

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
}

/// The loading phase of a Message Center message's content.
///
/// Reported by ``MessageCenterMessageContentView`` through its `phase` binding
/// so a host can present its own loading and error UI.
public enum MessageCenterMessageContentPhase: Sendable, Equatable {
    /// The message content is loading.
    case loading
    /// The message content failed to load.
    case error(MessageCenterMessageError)
    /// The message content finished loading.
    case loaded
}

extension View {
    /// Sets the style for the Message Center message view.
    /// - Parameters:
    ///     - style: The style to apply.
    public func messageCenterMessageViewStyle<S>(
        _ style: S
    ) -> some View where S: MessageViewStyle {
        self.environment(\.airshipMessageViewStyle, AnyMessageViewStyle(style: style))
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
        DefaultMessageCenterMessageContentView(
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

/// The default content view for a Message Center message.
///
/// Wraps ``MessageCenterMessageContentView`` with the SDK's built-in loading
/// indicator, error/retry UI, and fade-in behavior. Hosts that want to provide
/// their own loading and error presentation should use
/// ``MessageCenterMessageContentView`` directly.
private struct DefaultMessageCenterMessageContentView: View {
    @Environment(\.colorScheme)
    private var colorScheme

    @Environment(\.airshipMessageCenterTheme)
    private var theme

    @State
    private var messageLoadingPhase: MessageCenterMessageContentPhase = .loading

    @State
    private var opacity = 0.0

    @ObservedObject
    var viewModel: MessageCenterMessageViewModel
    let dismissAction: (@MainActor @Sendable () -> Void)?

    init(
        viewModel: MessageCenterMessageViewModel,
        dismissAction: (@MainActor @Sendable () -> Void)?
    ) {
        self.viewModel = viewModel
        self.dismissAction = dismissAction
    }

    var body: some View {
        let backgroundColor = self.colorScheme.airshipResolveColor(
            light: self.theme.messageViewBackgroundColor,
            dark: self.theme.messageViewBackgroundColorDark
        )

        ZStack {
            if let backgroundColor {
                backgroundColor.ignoresSafeArea()
            }

            MessageCenterMessageContentView(
                viewModel: viewModel,
                phase: self.$messageLoadingPhase,
                dismissAction: dismissAction
            )
            .opacity(self.opacity)
            .airshipOnChangeOf(self.messageLoadingPhase.isLoaded, initial: true) { isLoaded in
                guard isLoaded else { return }
                self.opacity = 1.0
                if Airship.isFlying {
                    Task {
                        await viewModel.markRead()
                    }
                }
            }
            .animation(.easeInOut(duration: 0.5), value: self.opacity)

            if case .loading = self.messageLoadingPhase {
                ProgressView()
            } else if case .error(let error) = self.messageLoadingPhase {
                if error == .messageGone {
                    VStack {
                        Text(
                            "ua_mc_no_longer_available".messageCenterLocalizedString
                        )
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding()
                    }
                } else {
                    VStack {
                        Text("ua_mc_failed_to_load".messageCenterLocalizedString)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .padding()

                        Button("ua_retry_button".messageCenterLocalizedString) {
                            self.messageLoadingPhase = .loading
                        }
                    }
                }
            }
        }
    }
}

