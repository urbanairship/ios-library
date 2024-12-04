/* Copyright Airship and Contributors */

import SwiftUI

struct EmptySectionLabel: View {
    @Environment(\.colorScheme)
    private var colorScheme

    // The empty message
    var label: String?

    /// The preference center theme
    var theme: PreferenceCenterTheme.ChannelSubscription?

    public var body: some View {
        if let label = label {
            SwiftUI.Label {
                Text(label)
                    .textAppearance(
                        theme?.emptyTextAppearance,
                        base: PreferenceCenterDefaults.subtitleAppearance,
                        colorScheme: colorScheme
                    )
            } icon: {
                Image(systemName: "info.circle")
                    .foregroundColor(.primary.opacity(0.5))
            }
            .padding(PreferenceCenterDefaults.smallPadding)
        }
    }
}
