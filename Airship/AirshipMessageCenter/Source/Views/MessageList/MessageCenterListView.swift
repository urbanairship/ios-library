/* Copyright Airship and Contributors */

import Combine
import Foundation
public import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

/// A view that displays a list of messages.
public struct MessageCenterListView: View {
    @Environment(\.editMode)
    private var editMode

    @Environment(\.colorScheme)
    private var colorScheme

    @Environment(\.airshipMessageCenterTheme)
    private var theme

    @StateObject
    private var viewModel = MessageCenterMessageListViewModel()

    @State
    private var listOpacity = 0.0

    @State
    private var isRefreshing = false

    /// Initializer.
    /// - Parameters:
    ///   - viewModel: The message center list view model.
    public init(viewModel: MessageCenterMessageListViewModel) {
        _viewModel = .init(wrappedValue: viewModel)
    }

    /// Initializer.
    /// - Parameters:
    ///   - predicate: A predicate to filter messages.
    public init(predicate: (any MessageCenterPredicate)? = nil) {
        _viewModel = .init(wrappedValue: .init(predicate: predicate))
    }

    @ViewBuilder
    private func makeCellContent(
        item: MessageCenterListItemViewModel,
        messageID: String
    ) -> some View {
        MessageCenterListItemView(viewModel: item)
    }
    
    @ViewBuilder
    private func makeCell(
        item: MessageCenterListItemViewModel,
        messageID: String
    ) -> some View {
        let accessibilityLabel = String(
            format: item.message.unread ? "ua_message_unread_description".messageCenterLocalizedString : "ua_message_description".messageCenterLocalizedString,
            item.message.title,
            AirshipDateFormatter.string(fromDate: item.message.sentDate, format: .relativeShortDate)
        )

        let cell = makeCellContent(item: item, messageID: messageID)
            .accessibilityLabel(
                accessibilityLabel
            ).accessibilityHint(
                "ua_message_cell_description".messageCenterLocalizedString
            )

        cell.listRowBackground(
            colorScheme.airshipResolveColor(light: theme.cellColor, dark: theme.cellColorDark)
        )
#if !os(tvOS)
        .listRowSeparator(
            (theme.cellSeparatorStyle == SeparatorStyle.none)
            ? .hidden : .automatic
        )
        .listRowSeparatorTint(colorScheme.airshipResolveColor(light: theme.cellSeparatorColor, dark: theme.cellSeparatorColorDark))
#endif
    }

    @ViewBuilder
    private func makeCell(messageID: String) -> some View {
        if let item = self.viewModel.messageItem(forID: messageID) {
#if !os(tvOS)
            makeCell(item: item, messageID: messageID)
#else
            /**
             * List items are not selectable by tvOS without a focusable element
             */
            Button(
                action: {
                    self.viewModel.selectedMessageID = messageID
                }) {
                    makeCell(item: item, messageID: messageID)
                }
                .buttonStyle(.plain)
#endif
        } else {
            EmptyView()
        }
    }

    private var isEditMode: Bool {
        self.editMode?.wrappedValue.isEditing ?? false
    }

    @ViewBuilder
    private func makeList() -> some View {
        let binding: Binding<Set<String>> = .init(
            get: {
                if isEditMode {
                    return self.viewModel.editModeSelection
                } else {
                    var set = Set<String>()
                    if let selectedMessageID = viewModel.selectedMessageID {
                        set.insert(selectedMessageID)
                    }
                    return set
                }
            },
            set: {
                if isEditMode {
                    self.viewModel.editModeSelection = $0
                } else {
                    self.viewModel.selectedMessageID = $0.first
                }
            }
        )

        List(selection: binding) {
            ForEach(self.viewModel.messages) { message in
                makeCell(messageID: message.id)
            }
            .onDelete { offsets in
                self.viewModel.delete(
                    messages: Set(offsets.map { self.viewModel.messages[$0].id })
                )
            }
        }
        .refreshable {
            await self.viewModel.refresh()
        }
        .disabled(self.viewModel.messages.isEmpty)
    }

    @ViewBuilder
    private func emptyMessageListMessage() -> some View {
        let refreshColor = colorScheme.airshipResolveColor(
            light: theme.refreshTintColor,
            dark: theme.refreshTintColorDark
        )

        VStack {
            Button {
                Task { @MainActor in
                    isRefreshing = true
                    await self.viewModel.refresh()
                    isRefreshing = false
                }
            } label: {
                ZStack {
                    if isRefreshing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(refreshColor ?? .primary)
                    }
                }
                .frame(height: 44)
                .background(Color.airshipTappableClear)
            }
            .disabled(isRefreshing)

            Text("ua_empty_message_list".messageCenterLocalizedString)
                .foregroundColor(refreshColor ?? .primary)
        }
        .opacity(1.0 - self.listOpacity)
    }

    @ViewBuilder
    /// The body of the view.
    public var body: some View {
        let listBackgroundColor = colorScheme.airshipResolveColor(
            light: theme.messageListBackgroundColor,
            dark: theme.messageListBackgroundColorDark
        )

        ZStack {
            if !self.viewModel.messagesLoaded {
                ProgressView().opacity(1.0 - self.listOpacity)
            } else if viewModel.messages.isEmpty {
                emptyMessageListMessage()
            } else {
                makeList()
                    .opacity(self.listOpacity)
                    .listBackground(listBackgroundColor)
                    .animation(.easeInOut(duration: 0.5), value: self.listOpacity)
                    .padding(.bottom, 60) // small spacing at bottom to avoid tab bars
            }
        }
        .airshipOnChangeOf(self.viewModel.messages) { messages in
            if messages.isEmpty {
                self.listOpacity = 0.0
            } else {
                self.listOpacity = 1.0
            }
        }
    }
}

fileprivate extension View {
    @ViewBuilder
    func listBackground(_ color: Color?) -> some View {
        if let color {
#if !os(tvOS)
            self.scrollContentBackground(.hidden).background(color)
#endif
        } else {
            self
        }
    }
}
