/* Copyright Urban Airship and Contributors */

import Combine
import Foundation
public import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Message Center View
public struct MessageCenterView: View {
    /// The message center state
    @ObservedObject
    private var controller: MessageCenterController

    /// Weak reference to the hosting view controller for UIKit appearance detection
    weak private var hostingController: UIViewController?

    @Environment(\.colorScheme)
    private var colorScheme

    @Environment(\.messageCenterDismissAction)
    private var dismissAction: (@MainActor @Sendable () -> Void)?

    @Environment(\.airshipMessageCenterTheme)
    private var theme

    @Environment(\.airshipMessageCenterNavigationStack)
    private var navigationStack

    @Environment(\.messageCenterViewStyle)
    private var style

    /// Default constructor
    /// - Parameters:
    ///   - controller: Controls navigation within the view
    ///   - hostingController: The UIViewController hosting this SwiftUI view used for UIKit navigation appearance detection
    public init(
        controller: MessageCenterController? = nil,
        hostingController: UIViewController? = nil
    ) {
        self.controller = if let controller {
            controller
        } else if Airship.isFlying {
            Airship.messageCenter.controller
        } else {
            MessageCenterController()
        }

        self.hostingController = hostingController
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
            navigationStack: self.navigationStack,
            dismissAction: self.dismissAction
        )

        let styledContent = style.makeBody(configuration: configuration)

        if let hostingController = hostingController {
            styledContent
                .modifier(
                    MessageCenterUIKitContextModifier(
                        hostingControllerRef: MessageCenterUIKitAppearance.WeakReference(hostingController)
                    )
                )
                .onAppear {
                    self.controller.isMessageCenterVisible = true
                }
                .onDisappear {
                    self.controller.isMessageCenterVisible = false
                }
        } else {
            styledContent
                .onAppear {
                    self.controller.isMessageCenterVisible = true
                }
                .onDisappear {
                    self.controller.isMessageCenterVisible = false
                }
        }
    }
}

// MARK: Styling

public protocol MessageCenterViewStyle: Sendable {
    associatedtype Body: View
    typealias Configuration = MessageCenterStyleConfiguration
    @MainActor
    func makeBody(configuration: Self.Configuration) -> Self.Body
}

public struct MessageCenterStyleConfiguration: Sendable {
    public struct Content: View {
        let controller: MessageCenterController
        let theme: MessageCenterTheme
        let colorScheme: ColorScheme
        let dismissAction: (() -> Void)?

        @State
        var editMode: EditMode = .inactive
        
        @State
        var selectedMessageID: String? = nil

        public var body: some View {
            MessageCenterListView(
                controller: controller,
                selectedMessageID: $selectedMessageID
            )
            .environment(\.editMode, $editMode)
        }
    }

    public let content: Content
    public let theme: MessageCenterTheme
    public let colorScheme: ColorScheme
    public let navigationStack: MessageCenterNavigationStack
    public let dismissAction: (@MainActor @Sendable () -> Void)?
}

/// Default Message Center style
struct DefaultMessageCenterViewStyle: MessageCenterViewStyle {

    @ViewBuilder
    private func makeBackButton(configuration: Configuration) -> some View {
        let backButtonColor = configuration.colorScheme.airshipResolveColor(
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

    @MainActor
    @ViewBuilder
    public func makeBody(configuration: Configuration) -> some View {
        let containerBackgroundColor: Color? = configuration.colorScheme.airshipResolveColor(
            light: configuration.theme.messageListContainerBackgroundColor,
            dark: configuration.theme.messageListContainerBackgroundColorDark
        )

        let content = configuration.content
            .airshipApplyIf(configuration.dismissAction != nil) { view in
                view.toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        makeBackButton(configuration: configuration)
                    }
                }
            }.navigationTitle(
                configuration.theme.navigationBarTitle ?? "ua_message_center_title".messageCenterLocalizedString
            )

        if #available(iOS 16.0, *) {
            let themedContent = content.airshipApplyIf(containerBackgroundColor != nil) { view in
                view.toolbarBackground(containerBackgroundColor!, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
            }

            switch (configuration.navigationStack) {
            
            case .split:
                MessageCenterNavigationSplitView(
                    configuration: configuration
                )
            case .default:
                NavigationStack {
                    themedContent
                }
            case .none:
                themedContent
            }

        } else {
            switch (configuration.navigationStack) {
            case .default, .split:
                NavigationView {
                    content.background(containerBackgroundColor)
                }
                .navigationViewStyle(.stack)
            case .none:
                content
            }
        }

    }
}

@available(iOS 16.0, *)
struct MessageCenterNavigationSplitView: View {
    
    let configuration: MessageCenterStyleConfiguration
        
    @State
    private var selectedMessageID: String?
    
    @Environment(\.messageCenterDetectedAppearance)
    private var detectedAppearance
    
    private var controller: MessageCenterController
    
    init(
        configuration: MessageCenterStyleConfiguration
    ) {
        self.configuration = configuration
        self.controller = configuration.content.controller
    }
    
    @State
    private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn
        
    var body: some View {
        
        let containerBackgroundColor: Color? = configuration.colorScheme.airshipResolveColor(
            light: configuration.theme.messageListContainerBackgroundColor,
            dark: configuration.theme.messageListContainerBackgroundColorDark
        )

        NavigationSplitView(columnVisibility: $columnVisibility) {
            NavigationStack(path: Binding {
                return self.controller.path
            } set: { path in
                self.controller.path = path
            }) {
                MessageCenterListView(
                    controller: controller,
                    selectedMessageID: $selectedMessageID
                )
                .navigationTitle(
                    configuration.theme.navigationBarTitle ?? "ua_message_center_title".messageCenterLocalizedString
                )
                .airshipApplyIf(containerBackgroundColor != nil) { view in
                    view.toolbarBackground(containerBackgroundColor!, for: .navigationBar)
                        .toolbarBackground(.visible, for: .navigationBar)
                }
            }
        } detail: {
            if let selectedMessageID {
                MessageCenterMessageView(
                    messageID: selectedMessageID,
                    title: nil,
                    dismissAction: {
                        self.selectedMessageID = nil
                    }
                )
                .environment(\.messageCenterDetectedAppearance, detectedAppearance)
                .onAppear {
                    self.controller.visibleMessageID = selectedMessageID
                }
                .onDisappear {
                    if (selectedMessageID == self.controller.visibleMessageID) {
                        self.controller.visibleMessageID = nil
                    }
                }
                .id(selectedMessageID)
            } else {
                Text("ua_message_not_selected".messageCenterLocalizedString)
            }
        }
    }
}

// Type-erased wrapper for MessageCenterViewStyle
private struct AnyMessageCenterViewStyle: MessageCenterViewStyle {
    private let _makeBody: @MainActor @Sendable (Configuration) -> AnyView

    init<S: MessageCenterViewStyle>(_ style: S) {
        _makeBody = { @MainActor configuration in
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

    var messageCenterDismissAction: (@MainActor @Sendable () -> Void)? {
        get { self[MessageCenterDismissActionKey.self] }
        set { self[MessageCenterDismissActionKey.self] = newValue }
    }
}

/// Sets the style for `MessageCenter`.
/// - Parameter style: The `MessageCenterViewStyle` to apply.
public extension View {
    func messageCenterViewStyle<S: MessageCenterViewStyle>(_ style: S) -> some View {
        self.environment(\.messageCenterViewStyle, AnyMessageCenterViewStyle(style))
    }
}


// MARK: Message center dismiss action
private struct MessageCenterDismissActionKey: EnvironmentKey {
    static let defaultValue: (@MainActor @Sendable () -> Void)? = nil
}

internal extension View {
    func addMessageCenterDismissAction(action: (@MainActor @Sendable () -> Void)?) -> some View {
        environment(\.messageCenterDismissAction, action)
    }
}


/// Message Center Navigation stack
public enum MessageCenterNavigationStack: Sendable {
    /// The Message Center will not be wrapped in a navigation stack
    case none

    ///The Message Center will be wrapped in NavigationSplitView on  iOS 16+, or a NavigationView.
    case split
    
    /// The Message Center will be wrapped in either a NavigationStack on iOS 16+, or a NavigationView.
    case `default`
}

struct MessageCenterNavigationStackKey: EnvironmentKey {
    static let defaultValue: MessageCenterNavigationStack = .default
}

extension EnvironmentValues {
    /// Airship preference theme environment value
    public var airshipMessageCenterNavigationStack: MessageCenterNavigationStack {
        get { self[MessageCenterNavigationStackKey.self] }
        set { self[MessageCenterNavigationStackKey.self] = newValue }
    }
}

// MARK: UIKit Context Modifier

struct MessageCenterUIKitContextModifier: ViewModifier {
    let hostingControllerRef: MessageCenterUIKitAppearance.WeakReference<UIViewController>
    @State private var detectedAppearance: MessageCenterUIKitAppearance.DetectedAppearance?

    func body(content: Content) -> some View {
        content
            .environment(\.messageCenterDetectedAppearance, detectedAppearance)
            .applyUIKitNavigationAppearance()
            .background(
                MessageCenterAppearanceDetector(
                    detectedAppearance: $detectedAppearance,
                    hostingControllerRef: hostingControllerRef
                )
                .frame(width: 0, height: 0)
                .hidden()
            )
    }
}

extension View {
    /// Sets the navigation stack for the Message Center.
    /// - Parameters:
    ///     - stack: The navigation stack
    @available(*, deprecated, renamed: "messageCenterNavigationStack", message: "Renamed to messageCenterNavigationStack. Use messageCenterNavigationStack instead.")
    public func messageeCenterNavigationStack(
        _ stack: MessageCenterNavigationStack
    )-> some View {
        environment(\.airshipMessageCenterNavigationStack, stack)
    }

    /// Sets the navigation stack for the Message Center.
    /// - Parameters:
    ///     - stack: The navigation stack
    public func messageCenterNavigationStack(
        _ stack: MessageCenterNavigationStack
    )-> some View {
        environment(\.airshipMessageCenterNavigationStack, stack)
    }
}
