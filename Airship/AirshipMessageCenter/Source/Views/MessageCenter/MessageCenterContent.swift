/* Copyright Airship and Contributors */

import Combine
import Foundation
public import SwiftUI

#if canImport(UIKit)
public import UIKit
#endif

#if canImport(AppKit)
public import AppKit
#endif

#if canImport(AirshipCore)
public import AirshipCore
#endif

/// The Message Center content view.
/// This view can be used to construct a custom Message Center. For a more turnkey solution, see `MessageCenterView`.
///
/// To use this view, a `MessageCenterController` must be supplied. The controller will be shared between the list and message views,
/// keeping the state in sync.
///
/// ### Using it with your own navigation stack:
/// ```swift
///    @StateObject
///    private var messageCenterController = MessageCenterController()
///
///    var body: some View {
///        NavigationStack(path: $messageCenterController.path) {
///            MessageCenterContent(controller: messageCenterController)
///                .navigationDestination(for: MessageCenterController.Route.self) { route in
///                    switch(route) {
///                    case .message(let messageID):
///                        MessageCenterMessageViewWithNavigation(messageID: messageID)
///                    @unknown default:
///                        fatalError()
///                    }
///                }
///        }
///    }
/// ```
///
/// ### Using it in a deprecated NavigationView or UIKIt:
///```swift
///     @StateObject
///     private var messageCenterController = MessageCenterController()
///
///     var body: some View {
///         NavigationView {
///             ZStack {
///                 MessageCenterContent(controller: self.messageCenterController)
///                 NavigationLink(
///                     destination: Group {
///                         if case .message(let messageID) = self.messageCenterController.path.last {
///                             MessageCenterMessageViewWithNavigation(messageID: messageID) {
///                                 // Clear selection on close
///                                 self.messageCenterController.path.removeAll()
///                             }
///                         } else {
///                             EmptyView()
///                         }
///                     },
///                     isActive: Binding(
///                         get: { self.messageCenterController.path.last != nil },
///                         set: { isActive in
///                             if !isActive { self.messageCenterController.path.removeAll() }
///                         }
///                     )
///                 ) {
///                     EmptyView()
///                 }
///                 .hidden()
///             }
///         }
///     }
///```
@MainActor
public struct MessageCenterContent: View {

    private enum Source {
        case external(MessageCenterMessageListViewModel)
        case predicate((any MessageCenterPredicate)?)
    }

    private let controller: MessageCenterController
    private let source: Source

    /// Weak reference to the hosting view controller for UIKit appearance detection
    weak private var hostingController: AirshipNativeViewController?

    /// Initializer.
    /// - Parameters:
    ///   - controller: The message center controller.
    ///   - listViewModel: The message center list view model.
    public init(
        controller: MessageCenterController,
        listViewModel: MessageCenterMessageListViewModel
    ) {
        self.controller = controller
        self.source = .external(listViewModel)
    }

    /// Initializer.
    /// - Parameters:
    ///   - controller: The message center controller.
    ///   - hostingController: A weak reference to the hosting controller to apply apperance changes.
    ///   - predicate: A predicate to filter messages.
    public init(
        controller: MessageCenterController,
        hostingController: AirshipNativeViewController? = nil,
        predicate: (any MessageCenterPredicate)? = nil
    ) {
        self.controller = controller
        self.hostingController = hostingController
        self.source = .predicate(predicate)
    }

    /// The body of the view.
    public var body: some View {
        switch source {
        case .external(let listViewModel):
            Content(controller: controller, hostingController: hostingController, listViewModel: listViewModel)
        case .predicate(let predicate):
            Owned(controller: controller, hostingController: hostingController, predicate: predicate)
        }
    }

    /// Owns the list view model's lifecycle for the self-owned (predicate-based) case only.
    private struct Owned: View {
        let controller: MessageCenterController
        weak var hostingController: AirshipNativeViewController?

        @StateObject
        private var listViewModel: MessageCenterMessageListViewModel

        init(
            controller: MessageCenterController,
            hostingController: AirshipNativeViewController?,
            predicate: (any MessageCenterPredicate)?
        ) {
            self.controller = controller
            self.hostingController = hostingController
            _listViewModel = StateObject(wrappedValue: MessageCenterMessageListViewModel(predicate: predicate))
        }

        var body: some View {
            Content(controller: controller, hostingController: hostingController, listViewModel: listViewModel)
        }
    }

    /// Renders the message list and syncs its selection with the controller. Always observes
    /// whatever list view model it's handed, whether that's owned by ``Owned`` or supplied
    /// externally by ``MessageCenterContent``'s caller.
    private struct Content: View {

        /// The message center state
        @ObservedObject
        private var controller: MessageCenterController

        @Environment(\.colorScheme)
        private var colorScheme

        @Environment(\.airshipMessageCenterTheme)
        private var theme

        @ObservedObject
        private var listViewModel: MessageCenterMessageListViewModel

        /// Weak reference to the hosting view controller for UIKit appearance detection
        weak private var hostingController: AirshipNativeViewController?

        init(
            controller: MessageCenterController,
            hostingController: AirshipNativeViewController?,
            listViewModel: MessageCenterMessageListViewModel
        ) {
            self.controller = controller
            self.hostingController = hostingController
            self.listViewModel = listViewModel
        }

        /// The body of the view.
        @ViewBuilder
        var body: some View {
            let content = MessageCenterListViewWithNavigation(viewModel: self.listViewModel)
                .airshipOnChangeOf(self.listViewModel.selectedMessageID, initial: true) { selection in
                    // sync list ID to the controller path
                    if let messageID = selection {
                        controller.navigate(messageID: messageID)
                    }
                }
                .airshipOnChangeOf(controller.path, initial: true) { _ in
                    // Sync controller path to the ID
                    if self.listViewModel.selectedMessageID != controller.currentMessageID {
                        self.listViewModel.selectedMessageID = controller.currentMessageID
                    }
                }

#if !os(macOS)
            if let hostingController = hostingController {
                content.modifier(
                    MessageCenterUIKitContextModifier(
                        hostingControllerRef: MessageCenterUIKitAppearance.WeakReference(hostingController)
                    )
                )
            } else {
                content
            }
#else
            content
#endif
        }
    }
}
