/* Copyright Airship and Contributors */

import Combine
import Foundation
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

@MainActor
struct MessageCenterNavigationStack: View {
    @Environment(\.colorScheme)
    private var colorScheme
    
    @Environment(\.airshipMessageCenterTheme)
    private var theme
    
    /// The message center state
    @ObservedObject
    private var controller: MessageCenterController
    
    /// Owned by ``MessageCenterAdaptiveNavigationView`` so it survives this container being swapped
    /// for the split one when the available width changes.
    @ObservedObject
    private var listViewModel: MessageCenterMessageListViewModel

#if !os(macOS)
    @Binding
    private var editMode: EditMode
#endif

#if !os(macOS)
    init(
        controller: MessageCenterController,
        listViewModel: MessageCenterMessageListViewModel,
        editMode: Binding<EditMode>
    ) {
        self.controller = controller
        self.listViewModel = listViewModel
        self._editMode = editMode
    }
#else
    init(
        controller: MessageCenterController,
        listViewModel: MessageCenterMessageListViewModel
    ) {
        self.controller = controller
        self.listViewModel = listViewModel
    }
#endif
    
    var body: some View {
        NavigationStack(path: $controller.path) {
            MessageCenterContent(controller: self.controller, listViewModel: self.listViewModel)
#if !os(macOS)
                .environment(\.editMode, $editMode)
                .navigationDestination(for: MessageCenterController.Route.self) { route in
                    switch(route) {
                    case .message(let messageID):
                        MessageCenterMessageViewWithNavigation(messageID: messageID, title: nil) {
                            self.controller.path.removeAll()
                        }
                    }
                }
#endif
        }
    }
}
