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
    
    @StateObject
    private var listViewModel: MessageCenterMessageListViewModel
    
#if !os(macOS)
    @State
    private var editMode: EditMode = .inactive
#endif
    
    init(controller: MessageCenterController, predicate: (any MessageCenterPredicate)?) {
        self.controller = controller
        _listViewModel = .init(wrappedValue: .init(predicate: predicate))
    }
    
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
