/* Copyright Airship and Contributors */

import SwiftUI

/// Prompt that appears within the Add Channel Prompt View when an opt-in operation is initiated
/// Subject to configuration by the user it tells users to check their email inbox, message app, etc.
/// Purely informational and it's only behavior is dismissing itself and it's parent the AddChannelPromptView
public struct ResultPromptView: View {
    var item: PreferenceCenterConfig.ContactManagementItem.ActionableMessage?

    /// The preference center theme
    var theme: PreferenceCenterTheme.ContactManagement?

    var onDismiss: () -> Void

    private var alertInternalPadding: CGFloat = 16
    private var alertExternalPadding: CGFloat = 16

    /// The minimum alert width - as defined by Apple
    private let promptMinWidth = 270.0

    /// The maximum alert width
    private let promptMaxWidth = 420.0

    public init(
        item: PreferenceCenterConfig.ContactManagementItem.ActionableMessage?,
        theme: PreferenceCenterTheme.ContactManagement?,
        onDismiss: @escaping () -> Void
    ) {
        self.item = item
        self.theme = theme
        self.onDismiss = onDismiss
    }

    public var body: some View {
        if let item = self.item {
            VStack(alignment: .leading, spacing: 8) {

                /// Title
                Text(item.title)
                    .textAppearance(
                        theme?.titleAppearance,
                        base: DefaultContactManagementSectionStyle.titleAppearance
                    )

                if let body = item.body {
                    /// Body
                    Text(body)
                        .textAppearance(
                            theme?.subtitleAppearance,
                            base: DefaultContactManagementSectionStyle.subtitleAppearance
                        )
                }

                HStack {
                    Spacer()
                    /// Button
                    LabeledButton(
                        item: item.button,
                        theme: self.theme,
                        action: onDismiss
                    )
                }
            }
            .padding(alertInternalPadding)
            .background(
                BackgroundShape(
                    color: theme?.backgroundColor ?? DefaultContactManagementSectionStyle.backgroundColor
                )
            )
            .padding(alertExternalPadding)
            .frame(minWidth: promptMinWidth, maxWidth: promptMaxWidth)
        }
    }
}
