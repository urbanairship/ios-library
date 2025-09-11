/* Copyright Airship and Contributors */

import Combine
import Foundation
public import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

/// A view that displays a list of messages as well as modifies the toolbars and navigation title.
@MainActor
public struct MessageCenterListViewWithNavigation: View {

    @Environment(\.messageCenterDismissAction)
    private var dismissAction: (@MainActor @Sendable () -> Void)?

    @Environment(\.editMode)
    private var editMode

    @Environment(\.colorScheme)
    private var colorScheme
    
    @Environment(\.airshipMessageCenterTheme)
    private var theme

    @StateObject
    private var viewModel: MessageCenterMessageListViewModel

    @Environment(\.messageCenterDetectedAppearance)
    private var detectedAppearance

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

    private var effectiveColors: MessageCenterEffectiveColors {
        MessageCenterEffectiveColors(
            detectedAppearance: detectedAppearance,
            theme: theme,
            colorScheme: colorScheme
        )
    }

    private var isEditMode: Bool {
        self.editMode?.wrappedValue.isEditing ?? false
    }

    private func editButton() -> some View {
        let color = isEditMode
        ? colorScheme.airshipResolveColor(light: theme.cancelButtonTitleColor, dark: theme.cancelButtonTitleColorDark)
        : effectiveColors.editButtonColor

        return EditButton()
            .foregroundColor(color)
            .accessibilityHint("ua_edit_messages_description".messageCenterLocalizedString)
    }

    private func markRead(messages: Set<String>) {
        withAnimation {
            self.editMode?.wrappedValue = .inactive
        }
        self.viewModel.markRead(messages: messages)
    }

    private func delete(messages: Set<String>) {
        withAnimation {
            self.editMode?.wrappedValue = .inactive
        }
        self.viewModel.delete(messages: messages)
    }

    private func markDeleteButton() -> some View {
        Button(
            "ua_mark_messages_read".messageCenterLocalizedString,
            systemImage: "trash",
            role: .destructive
        ) {
            self.viewModel.delete(messages: self.viewModel.editModeSelection)
        }
        .tint(
            colorScheme.airshipResolveColor(
                light: theme.deleteButtonTitleColor,
                dark: theme.deleteButtonTitleColorDark
            )
        )
        .accessibilityHint("ua_delete_messages".messageCenterLocalizedString)
        .disabled(self.viewModel.editModeSelection.isEmpty)
    }

    @ViewBuilder
    private func markReadButton() -> some View {
        Button(
            "ua_mark_messages_read".messageCenterLocalizedString,
            systemImage: "envelope.open"
        ) {
            markRead(messages: self.viewModel.editModeSelection)
        }
        .tint(
            colorScheme.airshipResolveColor(
                light: theme.markAsReadButtonTitleColor,
                dark: theme.markAsReadButtonTitleColorDark
            )
        )
        .disabled(self.viewModel.editModeSelection.isEmpty)
        .accessibilityHint("ua_mark_messages_read".messageCenterLocalizedString)
    }

    @ViewBuilder
    private func selectButton() -> some View {
        if self.viewModel.editModeSelection.count == self.viewModel.messages.count {
            selectNone()
        } else {
            selectAll()
        }
    }

    private func selectAll() -> some View {
        Button(
            "ua_select_all_messages".messageCenterLocalizedString
        ) {
            self.viewModel.editModeSelectAll()
        }
        .tint(
            colorScheme.airshipResolveColor(
                light: theme.selectAllButtonTitleColor,
                dark: theme.selectAllButtonTitleColorDark
            )
        )
        .accessibilityHint("ua_select_all_messages".messageCenterLocalizedString)
    }

    private func selectNone() -> some View {
        Button(
            "ua_select_none_messages".messageCenterLocalizedString
        ) {
            self.viewModel.editModeClearAll()
        }
        .tint(
            colorScheme.airshipResolveColor(
                light: theme.selectAllButtonTitleColor,
                dark: theme.selectAllButtonTitleColorDark
            )
        )
        .accessibilityHint("ua_select_none_messages".messageCenterLocalizedString)
    }

    /// The body of the view.
    public var body: some View {
        let containerBackgroundColor: Color? = colorScheme.airshipResolveColor(
            light: theme.messageListContainerBackgroundColor,
            dark: theme.messageListContainerBackgroundColorDark
        )

        let content = MessageCenterListView(viewModel: self.viewModel)
            .frame(maxHeight: .infinity)
            .applyUIKitNavigationAppearance()
            .toolbar {
#if os(iOS)
                if #available(iOS 26.0, *) {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        editButton()
                    }
                } else {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        editButton()
                    }
                }

                ToolbarItemGroup(placement: .bottomBar) {
                    selectButton()
                    Spacer()
                    markReadButton()
                    markDeleteButton()
                }
#else
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    editButton()
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    selectButton()
                    Spacer()
                    markReadButton()
                    Spacer()
                    markDeleteButton()
                }
#endif
            }
            .toolbar(isEditMode ? .visible : .hidden, for: .bottomBar)
            .airshipApplyIf(containerBackgroundColor != nil) { view in
                view.toolbarBackground(containerBackgroundColor!, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
            }
            .airshipApplyIf(dismissAction != nil) { view in
                view.toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        MessageCenterBackButton(dismissAction: dismissAction)
                    }
                }
            }
            .navigationTitle(
                theme.navigationBarTitle ?? "ua_message_center_title".messageCenterLocalizedString
            )

        if #available(iOS 26.0, *) {
            content.toolbar(
                isEditMode ? .hidden : .automatic,
                for: .tabBar
            )
            .ignoresSafeArea(edges: .bottom)
        } else {
            content
        }
    }
}
