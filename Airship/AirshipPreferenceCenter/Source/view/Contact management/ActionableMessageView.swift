/* Copyright Airship and Contributors */

import SwiftUI

/// Not sure why we need this, probably need to make a more abstract version of AddChannelPromptView and RemoveChannelView
// MARK: ActionableMessageView view: error/succeed alert view
public struct ActionableMessageView: View {
    var item: PreferenceCenterConfig.ContactManagementItem.ActionableMessage?

    /// The preference center theme
    var theme: PreferenceCenterTheme.ContactManagement?

    var action: (()->())?

    private var alertInternalPadding: CGFloat = 16

    public init(
        item: PreferenceCenterConfig.ContactManagementItem.ActionableMessage? = nil,
        theme: PreferenceCenterTheme.ContactManagement? = nil,
        action: (() -> Void)? = nil
    ) {
        self.item = item
        self.theme = theme
        self.action = action
    }

    public var body: some View {

        if let item = self.item {
            VStack(alignment: .leading) {

                /// Title
                Text(item.title)
                    .textAppearance(
                        theme?.titleAppearance,
                        base: DefaultContactManagementSectionStyle.titleAppearance
                    )

                /// Body
                Text(item.body)
                    .textAppearance(
                        theme?.subtitleAppearance,
                        base: DefaultContactManagementSectionStyle.subtitleAppearance
                    )

                HStack {
                    Spacer()
                    /// Button
                    LabeledButton(
                        item: item.button,
                        theme: self.theme,
                        action: action
                    )
                }
            }
            .padding(alertInternalPadding)
            .background(
                BackgroundShape(
                    color: theme?.backgroundColor ?? DefaultContactManagementSectionStyle.backgroundColor
                )
            )
            .frame(maxWidth: AddChannelPromptView.alertWidth)
        } else {
            Rectangle().foregroundColor(.red)
        }
    }
}
