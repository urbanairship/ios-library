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

    private let title: String?
    private let dismissAction: (@MainActor () -> Void)?

    /// Initializer.
    /// - Parameters:
    ///   - messageID: The message ID.
    ///   - title: The title to use until the message is loaded.
    ///   - dismissAction: A dismiss action.
    public init(
        messageID: String,
        title: String? = nil,
        dismissAction: (@MainActor () -> Void)? = nil
    ) {
        _messageViewModel = .init(wrappedValue: .init(messageID: messageID))
        self.title = title
        self.dismissAction = dismissAction
    }

    /// Initializer.
    /// - Parameters:
    ///   - viewModel: The message center message view model.
    ///   - title: The title to use until the message is loaded.
    ///   - dismissAction: A dismiss action.
    public init(
        viewModel: MessageCenterMessageViewModel,
        title: String? = nil,
        dismissAction: (@MainActor () -> Void)? = nil
    ) {
        _messageViewModel = .init(wrappedValue: viewModel)
        self.title = title
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

    /// The body of the view.
    public var body: some View {
        let containerColor = effectiveColors.navigationBarBackgroundColor ?? self.colorScheme.airshipResolveColor(
            light: self.theme.messageViewContainerBackgroundColor,
            dark: self.theme.messageViewContainerBackgroundColorDark
        )

        MessageCenterMessageView(viewModel: self.messageViewModel, dismissAction: dismissAction)
            .applyUIKitNavigationAppearance()
            .navigationBarBackButtonHidden(true) // Hide the default back button
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(self.messageViewModel.message?.title ?? self.title ?? "")
            .toolbar {

                // TODO, should we show back button always or only when presented?
                if self.presentationMode.wrappedValue.isPresented {
                    ToolbarItemGroup(placement: .navigationBarLeading) {
                        MessageCenterBackButton(dismissAction: dismiss)
                    }
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Delete button
                    deleteButton
                }


                // TODO: Fix this. Its not working on iOS 26 and should it be the same on the list view?
//
//                ToolbarItemGroup(placement: .principal) {
//                    // Custom title with detected color
//                    Text(self.messageViewModel.message?.title ?? self.title ?? "")
//                        .foregroundColor(effectiveColors.navigationTitleColor ?? Color.primary)
//                        .airshipApplyIf(detectedAppearance?.navigationTitleFont != nil) { text in
//                            text.font(detectedAppearance!.navigationTitleFont)
//                        }
//                }
            }
            .airshipApplyIf(containerColor != nil) { view in
                view.toolbarBackground(containerColor!, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
            }
    }

    @ViewBuilder
    private var deleteButton: some View {
        if theme.hideDeleteButton != true {
            Button("ua_delete_message".messageCenterLocalizedString) {
                Task {
                    await messageViewModel.delete()
                }
                dismiss()
            }.foregroundColor(effectiveColors.deleteButtonColor)
        }
    }

    private func dismiss() {
        if let dismissAction = self.dismissAction {
            dismissAction()
        }
        presentationMode.wrappedValue.dismiss()
    }
}

