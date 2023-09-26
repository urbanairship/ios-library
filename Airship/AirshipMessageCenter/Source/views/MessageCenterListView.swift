/* Copyright Urban Airship and Contributors */

import Combine
import Foundation
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Message Center list view
public struct MessageCenterListView: View {

    @State
    private var selection = Set<String>()

    @State
    private var editButtonColor: Color?

    @Environment(\.editMode)
    private var editMode

    @Environment(\.airshipMessageCenterTheme)
    private var theme

    @Environment(\.airshipMessageViewStyle)
    private var messageStyle

    @StateObject
    private var viewModel = MessageCenterListViewModel()

    @ObservedObject
    public var controller: MessageCenterController

    @State
    private var listOpacity = 0.0

    @State
    private var isRefreshing = false

    @State
    private var isActive = false
    
    private func markRead(messages: Set<String>) {
        editMode?.animation().wrappedValue = .inactive
        viewModel.markRead(messages: messages)
    }

    private func delete(messages: Set<String>) {
        editMode?.animation().wrappedValue = .inactive
        viewModel.delete(messages: messages)
    }

    @ViewBuilder
    private func makeCell(
        item: MessageCenterListItemViewModel,
        messageID: String
    ) -> some View {
        let cell = NavigationLink(
            destination: MessageCenterMessageView(
                messageID: messageID,
                title: item.message.title
            )
        ) {
            MessageCenterListItemView(viewModel: item)
        }

        if #available(iOS 15.0, *) {
            cell.listRowBackground(theme.cellColor)
                .listRowSeparator(
                    (theme.cellSeparatorStyle == SeparatorStyle.none)
                        ? .hidden : .automatic
                )
                .listRowSeparatorTint(theme.cellSeparatorColor)
        } else {
            cell.listRowBackground(theme.cellColor)
        }
    }

    @ViewBuilder
    private func makeList() -> some View {
        let list = List(selection: $selection) {
            ForEach(self.viewModel.messageIDs, id: \.self) { messageID in
                if let item = self.viewModel.messageItem(forID: messageID) {
                    makeCell(item: item, messageID: messageID)
                        .tag(messageID)
                } else {
                    EmptyView()
                }
            }
            .onDelete { offsets in
                delete(
                    messages: Set(offsets.map { viewModel.messageIDs[$0] })
                )
            }
            .onReceive(Just(self.selection)) { _ in
                if (editMode?.wrappedValue != .active) {
                    self.$selection.wrappedValue.removeAll()
                }
            }
            .onAppear{
                let _ = self.controller.$messageID
                    .sink {
                        isActive = ($0 != nil)
                    }
            }
        }

        if #available(iOS 15.0, *) {
            list.refreshable {
                await self.viewModel.refreshList()
            }
        } else {
            list
        }
    }

    @ViewBuilder
    private func makeContent() -> some View {
        
        let content = ZStack {
            makeList()
                .opacity(self.listOpacity)
                .animation(.easeInOut(duration: 0.5), value: self.listOpacity)
                .onReceive(self.viewModel.$messageIDs) { ids in
                    if ids.isEmpty {
                        self.listOpacity = 0.0
                    } else {
                        self.listOpacity = 1.0
                    }
                }

            if !self.viewModel.messagesLoaded {
                ProgressView()
                    .opacity(1.0 - self.listOpacity)
            } else if self.viewModel.messageIDs.isEmpty {
                VStack {
                    Button {
                        Task {
                            await self.viewModel.refreshList()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text("ua_empty_message_list".messageCenterlocalizedString)
                        .opacity(1.0 - self.listOpacity)
                }
            }
        }
        
        let destination = self.messageStyle.makeBody(
            configuration: MessageViewStyleConfiguration(
                messageID: self.controller.messageID ?? "",
                title: self.viewModel.messageItem(
                    forID: self.controller.messageID ?? ""
                )?.message.title,
                dismissAction: nil
            )
        )
            .onDisappear {
                self.controller.messageID = nil
            }
        
        if #available(iOS 16.0, *) {
            content
                .background(
                    NavigationLink(
                        "",
                        value: self.controller.messageID)
                    .navigationDestination(isPresented: $isActive) {
                        destination
                    }
                )
        } else {
            content
                .background(
                    NavigationLink(
                        "",
                        destination: destination,
                        isActive: $isActive
                    )
                )
        }
    }

    private func markDeleteButton() -> some View {
        Button(
            action: {
                delete(messages: selection)
            },
            label: {
                if self.selection.count > 0 {
                    Text(
                        "\("ua_delete_messages".messageCenterlocalizedString) (\(self.selection.count))"
                    )
                    .foregroundColor(theme.deleteButtonTitleColor)
                } else {
                    Text("ua_delete_messages".messageCenterlocalizedString)
                        .foregroundColor(theme.deleteButtonTitleColor)
                }
            }
        )
        .accessibilityHint("ua_delete_messages".messageCenterlocalizedString)
        .disabled(self.selection.isEmpty)
    }

    @ViewBuilder
    private func markReadButton() -> some View {
        Button(
            action: {
                markRead(messages: selection)
            },
            label: {
                if self.selection.count > 0 {
                    Text(
                        "\("ua_mark_messages_read".messageCenterlocalizedString) (\(self.selection.count))"
                    )
                    .foregroundColor(theme.markAsReadButtonTitleColor)
                } else {
                    Text("ua_mark_messages_read".messageCenterlocalizedString)
                        .foregroundColor(theme.markAsReadButtonTitleColor)
                }
            }
        )
        .disabled(self.selection.isEmpty)
        .accessibilityHint("ua_mark_messages_read".messageCenterlocalizedString)
    }

    @ViewBuilder
    private func selectButton() -> some View {
        if self.selection.count == self.viewModel.messageIDs.count {
            selectNone()
        } else {
            selectAll()
        }
    }

    private func selectAll() -> some View {
        Button {
            self.selection = Set(self.viewModel.messageIDs)
        } label: {
            Text("ua_select_all_messages".messageCenterlocalizedString)
                .foregroundColor(theme.selectAllButtonTitleColor)
        }
        .accessibilityHint("ua_select_all_messages".messageCenterlocalizedString)
    }

    private func selectNone() -> some View {
        Button {
            self.selection = Set()
        } label: {
            Text("ua_select_none_messages".messageCenterlocalizedString)
                .foregroundColor(theme.selectAllButtonTitleColor)
        }
        .accessibilityHint("ua_select_none_messages".messageCenterlocalizedString)
    }

    private func bottomToolBar() -> some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            if self.editMode?.wrappedValue.isEditing == true {
                HStack {
                    selectButton()
                    Spacer()
                    markReadButton()
                    Spacer()
                    markDeleteButton()
                }
            }
        }
    }

    private func editButton() -> some View {
        let isEditMode = self.editMode?.wrappedValue.isEditing ?? false
        let color =
            isEditMode
            ? theme.cancelButtonTitleColor : theme.editButtonTitleColor

        return EditButton().foregroundColor(color).accessibilityHint("ua_edit_messages_description".messageCenterlocalizedString)
    }

    @ViewBuilder
    private func refreshButton() -> some View {
        if isRefreshing {
            ProgressView()
        } else {
            Button {
                Task {
                    isRefreshing = true
                    await self.viewModel.refreshList()
                    isRefreshing = false
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(isRefreshing)
            .opacity(isRefreshing ? 0 : 1)
        }
    }

    private func leadingToolbar() -> some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            editButton()
            if #available(iOS 15, *) {} else {
                refreshButton()
            }
        }
    }

    @ViewBuilder
    public var body: some View {
        makeContent()
            .toolbar {
                bottomToolBar()
            }
            .toolbar {
                leadingToolbar()
            }

    }
}
