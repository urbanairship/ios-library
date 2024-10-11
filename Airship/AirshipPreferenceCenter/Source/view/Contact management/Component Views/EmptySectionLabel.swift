/* Copyright Airship and Contributors */

import SwiftUI

struct EmptySectionLabel: View {
    @Environment(\.colorScheme)
    private var colorScheme
    
    static let padding = EdgeInsets(top: 0, leading: 25, bottom: 5, trailing: 0)

    // The empty message
    var label: String?

    /// The preference center theme
    var theme: PreferenceCenterTheme.ChannelSubscription?

    var action: (()->())?

    public var body: some View {
        if let label = label {
            VStack(alignment: .leading) {
                HStack(spacing:12) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16))
                        .foregroundColor(.primary.opacity(0.5))
                    /// Message
                    Text(label)
                        .textAppearance(
                            theme?.emptyTextAppearance,
                            base: DefaultContactManagementSectionStyle.subtitleAppearance,
                            colorScheme: colorScheme
                        )
                    Spacer()
                }
            }
            .transition(.opacity)
            .padding(5)
        }
    }
}
