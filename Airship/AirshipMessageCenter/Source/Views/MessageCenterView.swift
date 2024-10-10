/* Copyright Urban Airship and Contributors */

import Combine
import Foundation
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Message Center View
public struct MessageCenterView: View {
    /// The message center state
    @ObservedObject
    private var controller: MessageCenterController

    @Environment(\.colorScheme)
    private var colorScheme

    @Environment(\.messageCenterDismissAction)
    private var dismissAction: (() -> Void)?

    @Environment(\.airshipMessageCenterTheme)
    private var theme

    @Environment(\.messageCenterViewStyle)
    private var style

    /// Default constructor
    /// - Parameters:
    ///     - controller: Controls navigation within the view
    public init(controller: MessageCenterController? = nil) {
        self.controller = if let controller {
            controller
        } else if Airship.isFlying {
            MessageCenter.shared.controller
        } else {
            MessageCenterController()
        }
    }

    @ViewBuilder
    public var body: some View {
        let content = MessageCenterStyleConfiguration.Content(
            controller: self.controller,
            theme: self.theme,
            colorScheme: self.colorScheme,
            dismissAction: self.dismissAction
        )

        let configuration = MessageCenterStyleConfiguration(
            content: content,
            theme: self.theme,
            colorScheme: self.colorScheme,
            dismissAction: self.dismissAction
        )

        let styledContent = style.makeBody(configuration: configuration)

        styledContent
            .onAppear {
                self.controller.isMessageCenterVisible = true
            }
            .onDisappear {
                self.controller.isMessageCenterVisible = false
            }
    }
}

// MARK: Styling

public protocol MessageCenterViewStyle {
    associatedtype Body: View
    typealias Configuration = MessageCenterStyleConfiguration
    func makeBody(configuration: Self.Configuration) -> Self.Body
}


public struct MessageCenterStyleConfiguration {
    public struct Content: View {
        let controller: MessageCenterController
        let theme: MessageCenterTheme
        let colorScheme: ColorScheme
        let dismissAction: (() -> Void)?

        @State
        var editMode: EditMode = .inactive

        public var body: some View {
            MessageCenterListView(controller: controller)
                .environment(\.editMode, $editMode)
        }
    }

    public let content: Content
    public let theme: MessageCenterTheme
    public let colorScheme: ColorScheme
    public let dismissAction: (() -> Void)?
}

/// Default Message Center style
public struct DefaultMessageCenterViewStyle: MessageCenterViewStyle {

    private let includeNavigation: Bool

    /// Default constructor
    /// - Parameters:
    ///     - includeNavigation: `true` if the view should create its own NavigationView or NavigationStack (iOS 16+)
    public init(includeNavigation: Bool = true) {
        self.includeNavigation = includeNavigation
    }

    @ViewBuilder
    private func makeBackButton(configuration: Configuration) -> some View {
        let backButtonColor = configuration.colorScheme.resolveColor(
            light: configuration.theme.backButtonColor,
            dark: configuration.theme.backButtonColorDark
        )

        Button(action: {
            configuration.dismissAction?()
        }) {
            Image(systemName: "chevron.backward")
                .scaleEffect(0.68)
                .font(Font.title.weight(.medium))
                .foregroundColor(backButtonColor)
        }
    }

    @ViewBuilder
    public func makeBody(configuration: Configuration) -> some View {
        let containerBackgroundColor: Color? = configuration.colorScheme.resolveColor(
            light: configuration.theme.messageListContainerBackgroundColor,
            dark: configuration.theme.messageListContainerBackgroundColorDark
        )

        let content = configuration.content
            .applyIf(containerBackgroundColor != nil) { view in
                view.background(containerBackgroundColor!)
            }.applyIf(configuration.dismissAction != nil) { view in
                view.toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        makeBackButton(configuration: configuration)
                    }
                }
            }.navigationTitle(
                configuration.theme.navigationBarTitle ?? "ua_message_center_title".messageCenterLocalizedString
            )

        if (includeNavigation) {
            if #available(iOS 16.0, *) {
                NavigationStack {
                    content
                }
            } else {
                NavigationView {
                    content
                }
                .navigationViewStyle(.stack)
            }
        } else  {
            content
        }
    }
}



// Type-erased wrapper for MessageCenterViewStyle
private struct AnyMessageCenterViewStyle: MessageCenterViewStyle {
    private var _makeBody: (Configuration) -> AnyView

    init<S: MessageCenterViewStyle>(_ style: S) {
        _makeBody = { configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

private struct MessageCenterViewStyleKey: EnvironmentKey {
    static let defaultValue: AnyMessageCenterViewStyle = AnyMessageCenterViewStyle(DefaultMessageCenterViewStyle())
}

fileprivate extension EnvironmentValues {
    var messageCenterViewStyle: AnyMessageCenterViewStyle {
        get { self[MessageCenterViewStyleKey.self] }
        set { self[MessageCenterViewStyleKey.self] = newValue }
    }

    var messageCenterDismissAction: (() -> Void)? {
        get { self[MessageCenterDismissActionKey.self] }
        set { self[MessageCenterDismissActionKey.self] = newValue }
    }
}

public extension View {
    func messageCenterViewStyle<S: MessageCenterViewStyle>(_ style: S) -> some View {
        self.environment(\.messageCenterViewStyle, AnyMessageCenterViewStyle(style))
    }
}


// MARK: Message center dismiss action
private struct MessageCenterDismissActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

internal extension View {
    func addMessageCenterDismissAction(action: (() -> Void)?) -> some View {
        environment(\.messageCenterDismissAction, action)
    }
}

extension ColorScheme {
    func resolveColor(light: Color?, dark: Color?) -> Color? {
        switch(self) {
        case .light:
            return light
        case .dark:
            return dark ?? light
        @unknown default:
            return light
        }
    }
}
