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

    var onCancel: ()->()
    var optOutAction: ()->()

    /// The minimum alert width - as defined by Apple
    private let promptMinWidth = 270.0

    /// The maximum alert width
    private let promptMaxWidth = 420.0

    private func dismiss() {
        onCancel()
    }

    @ViewBuilder
    private var promptViewContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            titleText.padding(.trailing, 16) // Pad out to prevent aliasing with the close button
            bodyText
            buttonView
            footer
        }
    }

    @ViewBuilder
    var promptView: some View {
        let dismissButtonColor = colorScheme.airshipResolveColor(light: theme?.buttonLabelAppearance?.color, dark: theme?.buttonLabelAppearance?.colorDark)

        GeometryReader { proxy in
            promptViewContent
                .padding(16)
                .addBackground(theme: theme, colorScheme: colorScheme)
                .addPreferenceCloseButton(
                    dismissButtonColor: dismissButtonColor ?? .primary,
                    dismissIconResource: "xmark",
                    contentDescription: item.view.closeButton?.contentDescription,
                    onUserDismissed: {
                        onCancel()
                    })
                .padding(16)
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
                base: DefaultContactManagementSectionStyle.titleAppearance,
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
                    base: DefaultContactManagementSectionStyle.subtitleAppearance,
                    colorScheme: colorScheme
                )
                .multilineTextAlignment(.leading)
        }
    }

    @ViewBuilder
    private var footer: some View {
        /// Footer
        if let footer = item.view.display.footer {
            Spacer()
                .frame(height: 20)
            FooterView(text: footer, textAppearance: theme?.subtitleAppearance ?? DefaultContactManagementSectionStyle.subtitleAppearance)
        }
    }

    @ViewBuilder
    private var buttonView: some View {
        let noText = item.view.onSuccess?.title == nil && item.view.onSuccess?.body == nil
        if item.view.cancelButton != nil {
            HStack {
                Spacer()
                HStack(alignment: .center, spacing: 12) {
                    cancelButton
                    submitButton
                }
                Spacer()
            }
            .padding(.top, noText ? 24 : 0)
        } else {
            HStack {
                Spacer()
                submitButton.padding(.top, noText ? 24 : 0)
            }
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
                action: optOutAction)
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
            .frame(minWidth: promptMinWidth, maxWidth: promptMaxWidth)
            .accessibilityAddTraits(.isModal)
    }
}
