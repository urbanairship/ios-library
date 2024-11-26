/* Copyright Airship and Contributors */

public import SwiftUI

/// Prompt that appears within the Add Channel Prompt View when an opt-in operation is initiated
/// Subject to configuration by the user it tells users to check their email inbox, message app, etc.
/// Purely informational and it's only behavior is dismissing itself and it's parent the AddChannelPromptView
public struct ResultPromptView: View {
    @Environment(\.colorScheme)
    private var colorScheme

    var item: PreferenceCenterConfig.ContactManagementItem.ActionableMessage?

    /// The preference center theme
    var theme: PreferenceCenterTheme.ContactManagement?

    var onDismiss: () -> Void

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
            VStack(alignment: .leading) {

                /// Title
                Text(item.title)
                    .textAppearance(
                        theme?.titleAppearance,
                        base: PreferenceCenterDefaults.titleAppearance,
                        colorScheme: colorScheme
                    )
                    .accessibilityAddTraits(.isHeader)

                if let body = item.body {
                    /// Body
                    Text(body)
                        .textAppearance(
                            theme?.subtitleAppearance,
                            base: PreferenceCenterDefaults.subtitleAppearance,
                            colorScheme: colorScheme
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
            .padding()
            .background(
                BackgroundShape(
                    color: colorScheme.airshipResolveColor(
                        light: theme?.backgroundColor,
                        dark: theme?.backgroundColorDark
                    ) ?? PreferenceCenterDefaults.promptBackgroundColor
                )
            )
            .padding()
            .frame(
                minWidth: PreferenceCenterDefaults.promptMinWidth,
                maxWidth: PreferenceCenterDefaults.promptMaxWidth
            )
            .accessibilityAddTraits(.isModal)
        }
    }
}
