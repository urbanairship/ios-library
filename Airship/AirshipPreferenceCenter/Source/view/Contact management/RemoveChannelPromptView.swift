/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

struct RemoveChannelPromptView: View {
    var item: PreferenceCenterConfig.ContactManagementItem.RemoveChannel

    /// The preference center theme
    var theme: PreferenceCenterTheme.ContactManagement?

    var onCancel: ()->()
    var optOutAction: (()->())?

    private func dismiss() {
        onCancel()
    }

    @ViewBuilder
    private var promptViewContent: some View {
        VStack(alignment: .leading) {
            titleText.padding(.trailing, 16) // Pad out to prevent aliasing with the close button
            bodyText
            button
            footer
        }
    }

    var promptView: some View {
        GeometryReader { proxy in
            promptViewContent
                .padding(16)
                .addBackground(theme: theme)
                .addPreferenceCloseButton(dismissButtonColor: .primary, dismissIconResource: "xmark", onUserDismissed: {
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
                base: DefaultContactManagementSectionStyle.titleAppearance
            )                
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var bodyText: some View {
        /// Body
        if let body = item.view.display.body {
            Text(body)
                .textAppearance(
                    theme?.subtitleAppearance,
                    base: DefaultContactManagementSectionStyle.subtitleAppearance
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
            Text(footer)
                .textAppearance(
                    theme?.subtitleAppearance,
                    base: DefaultContactManagementSectionStyle.subtitleAppearance
                )
        }
    }

    @ViewBuilder
    private var button: some View {
        if let optOutButton = item.view.acceptButton {
            HStack {
                Spacer()
                /// Opt out Button
                LabeledButton(
                    type: .destructiveType,
                    item: optOutButton,
                    theme: self.theme,
                    action: optOutAction
                )
            }
        }
    }

    var body: some View {
        promptView.frame(minWidth: min(UIScreen.main.bounds.width - 32, 420), maxWidth: 420)
    }
}
