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

    private let buttonTextMinScaleFactor: CGFloat = 0.65

    @State
    private var maxEditButtonsWidth: CGFloat = .infinity

    @State
    private var lastMaxEditButtonsWidth: CGFloat = 0

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

#if !os(tvOS)
    private func leadingToolbar() -> some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            editButton()
        }
    }
#endif

    private func bottomToolBar() -> some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            selectButton(maxWidth: maxEditButtonsWidth/3)
            Spacer()
            markReadButton(maxWidth: maxEditButtonsWidth/3)
            markDeleteButton(maxWidth: maxEditButtonsWidth/3)
        }
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

    private func markDeleteButton(maxWidth: CGFloat) -> some View {
        Button(
            action: {
                self.viewModel.delete(messages: self.viewModel.editModeSelection)
            },
            label: {
                if self.viewModel.editModeSelection.count > 0 {
                    Text(
                        "\("ua_delete_messages".messageCenterLocalizedString) (\(self.viewModel.editModeSelection.count))"
                    )
                    .lineLimit(1)
                    .foregroundColor(colorScheme.airshipResolveColor(light: theme.deleteButtonTitleColor, dark: theme.deleteButtonTitleColorDark))

                } else {
                    Text("ua_delete_messages".messageCenterLocalizedString)
                        .lineLimit(1)
                        .foregroundColor(colorScheme.airshipResolveColor(light: theme.deleteButtonTitleColor, dark: theme.deleteButtonTitleColorDark))
                }
            }
        )
        .accessibilityHint("ua_delete_messages".messageCenterLocalizedString)
        .disabled(self.viewModel.editModeSelection.isEmpty)
    }

    @ViewBuilder
    private func markReadButton(maxWidth: CGFloat) -> some View {
        Button(
            action: {
                markRead(messages: self.viewModel.editModeSelection)
            },
            label: {
                if self.viewModel.editModeSelection.count > 0 {
                    Text(
                        "\("ua_mark_messages_read".messageCenterLocalizedString) (\(self.viewModel.editModeSelection.count))"
                    )
                    .lineLimit(1)
                    .foregroundColor(colorScheme.airshipResolveColor(light: theme.markAsReadButtonTitleColor, dark: theme.markAsReadButtonTitleColorDark))

                } else {
                    Text("ua_mark_messages_read".messageCenterLocalizedString)
                        .lineLimit(1)
                        .foregroundColor(colorScheme.airshipResolveColor(light: theme.markAsReadButtonTitleColor, dark: theme.markAsReadButtonTitleColorDark))

                }
            }
        )
        .disabled(self.viewModel.editModeSelection.isEmpty)
        .accessibilityHint("ua_mark_messages_read".messageCenterLocalizedString)
    }

    @ViewBuilder
    private func selectButton(maxWidth: CGFloat) -> some View {
        if self.viewModel.editModeSelection.count == self.viewModel.messages.count {
            selectNone(maxWidth: maxWidth)
        } else {
            selectAll(maxWidth: maxWidth)
        }
    }

    private func selectAll(maxWidth: CGFloat) -> some View {
        Button {
            self.viewModel.editModeSelectAll()
        } label: {
            Text("ua_select_all_messages".messageCenterLocalizedString)
                .lineLimit(1)
                .foregroundColor(colorScheme.airshipResolveColor(light: theme.selectAllButtonTitleColor, dark: theme.selectAllButtonTitleColorDark))
        }
        .accessibilityHint("ua_select_all_messages".messageCenterLocalizedString)
    }

    private func selectNone(maxWidth: CGFloat) -> some View {
        Button {
            self.viewModel.editModeClearAll()
        } label: {
            Text("ua_select_none_messages".messageCenterLocalizedString)
                .lineLimit(1)
                .foregroundColor(
                    colorScheme.airshipResolveColor(
                        light: theme.selectAllButtonTitleColor,
                        dark: theme.selectAllButtonTitleColorDark
                    )
                )
        }
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
                leadingToolbar()
                bottomToolBar()
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
