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

    /// The message center state
    @ObservedObject
    private var controller: MessageCenterController

    @Environment(\.colorScheme)
    private var colorScheme

    @Environment(\.airshipMessageCenterTheme)
    private var theme

    @StateObject
    private var listViewModel: MessageCenterMessageListViewModel
    
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
        _listViewModel = .init(wrappedValue: listViewModel)
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
        _listViewModel = .init(wrappedValue: .init(predicate: predicate))
    }

    /// The body of the view.
    @ViewBuilder
    public var body: some View {
        let content = MessageCenterListViewWithNavigation(viewModel: self.listViewModel)
            .airshipOnChangeOf(self.listViewModel.selectedMessageID) { selection in
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
