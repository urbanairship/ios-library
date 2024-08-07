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

    @Environment(\.colorScheme) private var colorScheme

    @Environment(\.airshipMessageCenterTheme)
    private var theme

    @Environment(\.airshipMessageCenterPredicate)
    private var predicate

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
    
    @State
    private var messageIDs: [String] = []
    
    private func markRead(messages: Set<String>) {
        editMode?.animation().wrappedValue = .inactive
        viewModel.markRead(messages: messages)
    }

    private func delete(messages: Set<String>) {
        editMode?.animation().wrappedValue = .inactive
        viewModel.delete(messages: messages)
    }

    @ViewBuilder
    private func makeDestination(messageID: String, title: String?) -> some View {
        MessageCenterMessageView(
            messageID: messageID,
            title: title
        )
        .onAppear {
            self.controller.visibleMessageID = messageID
        }
        .onDisappear {
            if (messageID == self.controller.visibleMessageID) {
                self.controller.visibleMessageID = nil
            }
        }
        .id(messageID)
    }

    @ViewBuilder
    private func makeCell(
        item: MessageCenterListItemViewModel,
        messageID: String
    ) -> some View {
        let accessibilityLabel = String(format: item.message.unread ? "ua_message_unread_description".messageCenterLocalizedString : "ua_message_description".messageCenterLocalizedString, item.message.title,  AirshipDateFormatter.string(fromDate: item.message.sentDate, format: .relativeShortDate))

        let cell = NavigationLink(
            destination: makeDestination(messageID: messageID, title: item.message.title)
        ) {
            MessageCenterListItemView(viewModel: item)
        }.accessibilityLabel(
            accessibilityLabel
        )
        .accessibilityHint(
            "ua_message_cell_description".messageCenterLocalizedString
        )

        if #available(iOS 15.0, *) {
            cell.listRowBackground(theme.cellColor?.adaptiveColor(for: colorScheme, darkVariation: theme.cellColorDark))
                .listRowSeparator(
                    (theme.cellSeparatorStyle == SeparatorStyle.none)
                        ? .hidden : .automatic
                )
                .listRowSeparatorTint(theme.cellSeparatorColor?.adaptiveColor(for: colorScheme, darkVariation: theme.cellSeparatorColorDark))
        } else {
            cell.listRowBackground(theme.cellColor?.adaptiveColor(for: colorScheme, darkVariation: theme.cellColorDark))
        }
    }

    struct ListBackgroundModifier: ViewModifier {
        @ViewBuilder
        func body(content: Content) -> some View {
            if #available(iOS 16.0, *) {
                content
                    .scrollContentBackground(.hidden)
            } else {
                content
            }
        }
    }

    @ViewBuilder
    private func makeList() -> some View {
        let list = List(selection: $selection) {
            ForEach(self.messageIDs, id: \.self) { messageID in
                if let item = self.viewModel.messageItem(forID: messageID) {
                    makeCell(item: item, messageID: messageID)
                        .tag(messageID)
                } else {
                    EmptyView()
                }
            }
            .onDelete { offsets in
                delete(
                    messages: Set(offsets.map { self.messageIDs[$0] })
                )
            }
            .onReceive(Just(self.selection)) { _ in
                if (editMode?.wrappedValue != .active) {
                    self.$selection.wrappedValue.removeAll()
                }
            }
            .onReceive(self.controller.$messageID) { messageID in
                isActive = (messageID != nil)
            }
            .onReceive(self.viewModel.$messages) { messages in
                self.messageIDs = messages.filter { message in
                    if let predicate = self.predicate {
                        return predicate.evaluate(message: message)
                    }
                    return true
                }
                .map { $0.id }
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
        let listBackgroundColor = theme
            .messageListBackgroundColor?
            .adaptiveColor(
                for: colorScheme,
                darkVariation: theme.messageListBackgroundColorDark
            )

        let content = ZStack {
            makeList()
                .applyIf(listBackgroundColor != nil, transform: { view in
                    view.modifier(ListBackgroundModifier())
                    view.background(listBackgroundColor)
                })
                .opacity(self.listOpacity)
                .animation(.easeInOut(duration: 0.5), value: self.listOpacity)
                .onChange(of: self.messageIDs) { ids in
                    if ids.isEmpty {
                        self.listOpacity = 0.0
                    } else {
                        self.listOpacity = 1.0
                    }
                }

            if !self.viewModel.messagesLoaded {
                ProgressView()
                    .appearanceTint()
                    .opacity(1.0 - self.listOpacity)
            } else if self.messageIDs.isEmpty {
                VStack {
                    refreshButton()
                    Text("ua_empty_message_list".messageCenterLocalizedString)
                        .opacity(1.0 - self.listOpacity)
                }
            }
        }

        let selected = self.controller.messageID ?? ""
        let destination = makeDestination(
            messageID: selected,
            title: self.viewModel.messageItem(forID: selected)?.message.title
        )

        if #available(iOS 16.0, *) {
            content.background(
                NavigationLink("", value: selected)
                .navigationDestination(isPresented: $isActive) {
                    destination
                }
            )
        } else {
            content.background(
                NavigationLink("", destination: destination, isActive: $isActive)
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
                        "\("ua_delete_messages".messageCenterLocalizedString) (\(self.selection.count))"
                    )
                    .foregroundColor(theme.deleteButtonTitleColor?.adaptiveColor(for: colorScheme, darkVariation: theme.deleteButtonTitleColorDark))
                } else {
                    Text("ua_delete_messages".messageCenterLocalizedString)
                        .foregroundColor(theme.deleteButtonTitleColor?.adaptiveColor(for: colorScheme, darkVariation: theme.deleteButtonTitleColorDark))
                }
            }
        )
        .accessibilityHint("ua_delete_messages".messageCenterLocalizedString)
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
                        "\("ua_mark_messages_read".messageCenterLocalizedString) (\(self.selection.count))"
                    )
                    .foregroundColor(theme.markAsReadButtonTitleColor?.adaptiveColor(for: colorScheme, darkVariation: theme.markAsReadButtonTitleColorDark))
                } else {
                    Text("ua_mark_messages_read".messageCenterLocalizedString)
                        .foregroundColor(theme.markAsReadButtonTitleColor?.adaptiveColor(for: colorScheme, darkVariation: theme.markAsReadButtonTitleColorDark))
                }
            }
        )
        .disabled(self.selection.isEmpty)
        .accessibilityHint("ua_mark_messages_read".messageCenterLocalizedString)
    }

    @ViewBuilder
    private func selectButton() -> some View {
        if self.selection.count == self.messageIDs.count {
            selectNone()
        } else {
            selectAll()
        }
    }

    private func selectAll() -> some View {
        Button {
            self.selection = Set(self.messageIDs)
        } label: {
            Text("ua_select_all_messages".messageCenterLocalizedString)
                .foregroundColor(theme.selectAllButtonTitleColor?.adaptiveColor(for: colorScheme, darkVariation: theme.selectAllButtonTitleColorDark))
        }
        .accessibilityHint("ua_select_all_messages".messageCenterLocalizedString)
    }

    private func selectNone() -> some View {
        Button {
            self.selection = Set()
        } label: {
            Text("ua_select_none_messages".messageCenterLocalizedString)
                .foregroundColor(theme.selectAllButtonTitleColor?.adaptiveColor(for: colorScheme, darkVariation: theme.selectAllButtonTitleColorDark))
        }
        .accessibilityHint("ua_select_none_messages".messageCenterLocalizedString)
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
        ? theme.cancelButtonTitleColor?.adaptiveColor(for: colorScheme, darkVariation: theme.cancelButtonTitleColorDark) :
        theme.editButtonTitleColor?.adaptiveColor(for: colorScheme, darkVariation: theme.editButtonTitleColorDark)

        return EditButton()
            .foregroundColor(color)
            .accessibilityHint("ua_edit_messages_description".messageCenterLocalizedString)
    }

    @ViewBuilder
    private func refreshButton() -> some View {
        let refreshColor = theme.refreshTintColor?.adaptiveColor(for: colorScheme, darkVariation: theme.refreshTintColorDark)

        if isRefreshing {
            ProgressView()
                .appearanceTint()
        } else {
            Button {
                Task {
                    isRefreshing = true
                    await self.viewModel.refreshList()
                    isRefreshing = false
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(refreshColor)
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
