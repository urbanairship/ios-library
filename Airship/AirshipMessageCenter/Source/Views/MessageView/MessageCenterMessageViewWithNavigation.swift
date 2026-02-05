/* Copyright Airship and Contributors */

import Combine
import Foundation
public import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

/// A view that displays a message as well as modifies the toolbars and navigation title.
@MainActor
public struct MessageCenterMessageViewWithNavigation: View {

    @Environment(\.presentationMode)
    private var presentationMode: Binding<PresentationMode>

    @Environment(\.colorScheme)
    private var colorScheme

    @Environment(\.airshipMessageCenterTheme)
    private var theme

    @Environment(\.messageCenterDetectedAppearance)
    private var detectedAppearance

    @State
    private var opacity = 0.0

    @StateObject
    private var messageViewModel: MessageCenterMessageViewModel

    private let showBackButton: Bool?
    private let title: String?
    private let dismissAction: (@MainActor () -> Void)?

    @State
    private var isDismissed = false // Add this state

    /// Initializer.
    /// - Parameters:
    ///   - messageID: The message ID.
    ///   - title: The title to use until the message is loaded.
    ///   - showBackButton: Flag to show or hide the back button. If not set, back button will be displayed if it has a presentationMode.
    ///   - dismissAction: A dismiss action.
    public init(
        messageID: String,
        title: String? = nil,
        showBackButton: Bool? = nil,
        dismissAction: (@MainActor () -> Void)? = nil
    ) {
        _messageViewModel = .init(wrappedValue: .init(messageID: messageID))
        self.title = title
        self.showBackButton = showBackButton
        self.dismissAction = dismissAction
    }

    /// Initializer.
    /// - Parameters:
    ///   - viewModel: The message center message view model.
    ///   - title: The title to use until the message is loaded.
    ///   - showBackButton: Flag to show or hide the back button. If not set, back button will be displayed if it has a presentationMode.
    ///   - dismissAction: A dismiss action.
    public init(
        viewModel: MessageCenterMessageViewModel,
        title: String? = nil,
        showBackButton: Bool? = nil,
        dismissAction: (@MainActor () -> Void)? = nil
    ) {
        _messageViewModel = .init(wrappedValue: viewModel)
        self.title = title
        self.showBackButton = showBackButton
        self.dismissAction = dismissAction
    }

    /// Prioritizes theme values -> inherited appearance -> defaults
    private var effectiveColors: MessageCenterEffectiveColors {
        MessageCenterEffectiveColors(
            detectedAppearance: detectedAppearance,
            theme: theme,
            colorScheme: colorScheme
        )
    }

    private var shouldShowBackButton: Bool {
        if let showBackButton {
            return showBackButton
        }

        return showBackButton ?? self.presentationMode.wrappedValue.isPresented
    }

    /// The body of the view.
    public var body: some View {
        let containerColor = effectiveColors.navigationBarBackgroundColor ?? self.colorScheme.airshipResolveColor(
            light: self.theme.messageViewContainerBackgroundColor,
            dark: self.theme.messageViewContainerBackgroundColorDark
        )

        MessageCenterMessageView(
            viewModel: self.messageViewModel,
            dismissAction: dismiss
        )
            .applyUIKitNavigationAppearance()
            .navigationBarBackButtonHidden(true) // Hide the default back button
#if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .navigationTitle(self.messageViewModel.message?.title ?? self.title ?? "")
            .toolbar {
                if shouldShowBackButton {
                    ToolbarItemGroup(placement: .navigationBarLeading) {
                        MessageCenterBackButton(dismissAction: dismiss)
                    }
                }

#if os(iOS)
                if #available(iOS 26.0, *) {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        deleteButton
                    }
                } else {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        deleteButton
                    }
                }
#else
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    deleteButton
                }
#endif

                if effectiveColors.navigationTitleColor != nil || detectedAppearance?.navigationTitleFont != nil {
                    ToolbarItemGroup(placement: .principal) {
                        // Custom title with detected color
                        Text(self.messageViewModel.message?.title ?? self.title ?? "")
                            .foregroundColor(effectiveColors.navigationTitleColor)
                            .airshipApplyIf(detectedAppearance?.navigationTitleFont != nil) { text in
                                text.font(detectedAppearance!.navigationTitleFont)
                            }
                    }
                }
            }
            .airshipApplyIf(containerColor != nil) { view in
                let visibility: Visibility = if #available(iOS 26.0, *) {
                    .automatic
                } else {
                    .visible
                }
                view.toolbarBackground(containerColor!, for: .navigationBar)
                    .toolbarBackground(visibility, for: .navigationBar)
            }
    }

    @ViewBuilder
    private var deleteButton: some View {
        if theme.hideDeleteButton != true {
            Button(
                "ua_delete_message".messageCenterLocalizedString,
                systemImage: "trash",
                role: .destructive
            ) {
                Task {
                    await messageViewModel.delete()
                }
                dismiss()
            }
            .tint(effectiveColors.deleteButtonColor)
        }
    }

    private func dismiss() {
        guard !isDismissed else { return }
        isDismissed = true

        if let dismissAction = self.dismissAction {
            dismissAction()
        }
        messageViewModel.thomasDismissHandle.dismiss()
        presentationMode.wrappedValue.dismiss()
    }
}

