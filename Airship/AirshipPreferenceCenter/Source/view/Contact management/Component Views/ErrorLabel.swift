/* Copyright Airship and Contributors */

import SwiftUI

/// Error text view that appears under the add channel fields when an error occurs
public struct ErrorLabel: View {

    public var message: String?
    var theme: PreferenceCenterTheme.ContactManagement?

    public init(
        message: String?,
        theme: PreferenceCenterTheme.ContactManagement?
    ) {
        self.message = message
        self.theme = theme
    }

    public var body: some View {
        if let errorMessage = self.message {
            HStack (alignment: .top){
                Text(errorMessage)
                    .textAppearance(
                        theme?.errorAppearance,
                        base: DefaultContactManagementSectionStyle.defaultErrorAppearance
                    )
                    .lineLimit(2)
            }
        }
    }
}
