/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Prompt that appears when a opt-out button tap occurs.
struct RemoveChannelPromptView: View {
    @Environment(\.colorScheme)
    private var colorScheme

    var item: PreferenceCenterConfig.ContactManagementItem.RemoveChannel

    /// The preference center theme
    var theme: PreferenceCenterTheme.ContactManagement?

    var onCancel: () -> Void
    var optOutAction: () -> Void

    private func dismiss() {
        onCancel()
    }

    @ViewBuilder
    private var promptViewContent: some View {
        VStack(alignment: .leading) {
            titleText
                .padding(.trailing) // Pad out to prevent aliasing with the close button
            bodyText
                .padding(.vertical)
            buttonView
            footer
        }
    }

    @ViewBuilder
    var promptView: some View {
        let dismissButtonColor = colorScheme.airshipResolveColor(light: theme?.buttonLabelAppearance?.color, dark: theme?.buttonLabelAppearance?.colorDark)

        GeometryReader { proxy in
            promptViewContent
                .padding()
                .addPromptBackground(theme: theme, colorScheme: colorScheme)
                .addPreferenceCloseButton(
                    dismissButtonColor: dismissButtonColor ?? .primary,
                    dismissIconResource: "xmark",
                    contentDescription: item.view.closeButton?.contentDescription,
                    onUserDismissed: {
                        onCancel()
                    })
                .padding()
                .position(x: proxy.frame(in: .local).midX, y: proxy.frame(in: .local).midY)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var titleText: some View {
        /// Title
        Text(item.view.display.title)
            .textAppearance(
                theme?.titleAppearance,
                base: PreferenceCenterDefaults.titleAppearance,
                colorScheme: colorScheme
            )
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var bodyText: some View {
        /// Body
        if let body = item.view.display.body {
            Text(body)
                .textAppearance(
                    theme?.subtitleAppearance,
                    base: PreferenceCenterDefaults.subtitleAppearance,
                    colorScheme: colorScheme
                )
                .multilineTextAlignment(.leading)
        }
    }

    @ViewBuilder
    private var footer: some View {
        /// Footer
        if let footer = item.view.display.footer {
            FooterView(text: footer, textAppearance: theme?.subtitleAppearance ?? PreferenceCenterDefaults.subtitleAppearance)
        }
    }

    @ViewBuilder
    private var buttonView: some View {
        HStack {
            Spacer()
            if item.view.cancelButton != nil {
                cancelButton
                    .padding(.trailing)
            }
            submitButton
        }
    }

    @ViewBuilder
    private var submitButton: some View {
        if let optOutButton = item.view.submitButton {
            /// Opt out Button
            LabeledButton(
                type: .destructiveType,
                item: optOutButton,
                theme: self.theme,
                action: optOutAction
            )
        }
    }

    @ViewBuilder
    private var cancelButton: some View {
        if let cancelButton = item.view.cancelButton {
            HStack {
                Spacer()
                /// Opt out Button
                LabeledButton(
                    type: .outlineType,
                    item: cancelButton,
                    theme: self.theme,
                    action: onCancel
                )
            }
        }
    }

    var body: some View {
        promptView
            .frame(
                minWidth: PreferenceCenterDefaults.promptMinWidth,
                maxWidth: PreferenceCenterDefaults.promptMaxWidth
            )
            .accessibilityAddTraits(.isModal)
    }
}
