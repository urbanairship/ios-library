/* Copyright Airship and Contributors */

import SwiftUI

/// Error text view that appears under the add channel fields when an error occurs
struct ErrorLabel: View {
    @Environment(\.colorScheme)
    private var colorScheme

    var message: String?
    var theme: PreferenceCenterTheme.ContactManagement?

    init(
        message: String?,
        theme: PreferenceCenterTheme.ContactManagement?
    ) {
        self.message = message
        self.theme = theme
    }

    var body: some View {
        if let errorMessage = self.message {
            HStack (alignment: .top){
                Text(errorMessage)
                    .textAppearance(
                        theme?.errorAppearance,
                        base: PreferenceCenterDefaults.errorAppearance,
                        colorScheme: colorScheme
                    )
                    .lineLimit(2)
            }
        }
    }
}
