/* Copyright Airship and Contributors */

import Combine
import Foundation
import SwiftUI

import AirshipCore
@_spi(AirshipInternal) import AirshipBasement

@MainActor
struct MessageCenterNavigationSplitView: View {

    @ObservedObject
    private var controller: MessageCenterController

    /// Owned by ``MessageCenterAdaptiveNavigationView`` so it survives this container being swapped
    /// for the stack one when the available width changes.
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

    @ViewBuilder
    private var sidebar: some View {
        NavigationStack {
            let content = MessageCenterContent(controller: self.controller, listViewModel: self.listViewModel)
            content
#if !os(macOS)
                .environment(\.editMode, $editMode)
                .airshipOnChangeOf(editMode) { editMode in
                    if !editMode.isEditing, let last = self.listViewModel.selectedMessageID {
                        DispatchQueue.main.async {
                            self.listViewModel.selectedMessageID = last
                        }
                    }
                }
#endif
        }
    }

    @ViewBuilder
    private var detailView: some View {
        Group {
            if let messageID = self.controller.currentMessageID {
                MessageCenterMessageViewWithNavigation(messageID: messageID) {
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

    @ViewBuilder
    public var body: some View {
        NavigationSplitView {
            self.sidebar
        } detail: {
            NavigationStack {
                self.detailView
            }
        }
    }
}
