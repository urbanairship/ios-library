/* Copyright Airship and Contributors */

import Combine
import Foundation
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

@MainActor
struct MessageCenterNavigationSplitView: View {

    @ObservedObject
    private var controller: MessageCenterController

    @StateObject
    private var listViewModel: MessageCenterMessageListViewModel

    @State
    private var editMode: EditMode = .inactive

    init(controller: MessageCenterController, predicate: (any MessageCenterPredicate)?) {
        self.controller = controller
        _listViewModel = .init(wrappedValue: .init(predicate: predicate))
    }

    @ViewBuilder
    public var body: some View {
        NavigationSplitView {
            NavigationStack {
                MessageCenterContent(controller: self.controller, listViewModel: self.listViewModel)
                    .environment(\.editMode, $editMode)
                    .airshipOnChangeOf(editMode) { editMode in
                        // Restores selceion state after edit mode exits
                        if !editMode.isEditing, let last = self.listViewModel.selectedMessageID {
                            DispatchQueue.main.async {
                                self.listViewModel.selectedMessageID = last
                            }
                        }
                    }
            }
        } detail: {
            NavigationStack {
                Group {
                    if let messageID = self.controller.currentMessageID {
                        MessageCenterMessageViewWithNavigation(messageID: messageID, title: nil) {
                            self.controller.path.removeAll { $0 == .message(messageID) }
                        }
                        .id(messageID)
                    } else {
                        Text("Select a message")
                            .font(.title)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}
