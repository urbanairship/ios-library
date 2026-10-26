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

#if os(iOS)
    private let usesArrangementView: Bool
#endif

#if !os(macOS)
    init(
        controller: MessageCenterController,
        listViewModel: MessageCenterMessageListViewModel,
        editMode: Binding<EditMode>,
        usesArrangementView: Bool = false
    ) {
        self.controller = controller
        self.listViewModel = listViewModel
        self._editMode = editMode
#if os(iOS)
        self.usesArrangementView = usesArrangementView
#endif
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
    private var navigationSplitView: some View {
        NavigationSplitView {
            self.sidebar
        } detail: {
            NavigationStack {
                self.detailView
            }
        }
    }

    @ViewBuilder
    public var body: some View {
#if os(iOS) && canImport(SwiftUI, _version: 8.0.85)
        // Compiled only against the iOS 27.1 SDK so Xcode 27.0 still builds.
        if usesArrangementView, #available(iOS 27.1, *) {
            ArrangementView {
                self.sidebar
            } secondary: {
                NavigationStack {
                    self.detailView
                }
            }
            .arrangementViewStyle(.split)
        } else {
            self.navigationSplitView
        }
#else
        self.navigationSplitView
#endif
    }
}
