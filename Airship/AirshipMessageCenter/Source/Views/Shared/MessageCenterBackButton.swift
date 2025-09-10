/* Copyright Airship and Contributors */

import Combine
import Foundation
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

@MainActor
struct MessageCenterBackButton: View {
    @Environment(\.colorScheme)
    private var colorScheme

    @Environment(\.airshipMessageCenterTheme)
    private var theme

    @Environment(\.airshipMessageCenterPredicate)
    private var predicate

    var dismissAction: (@MainActor @Sendable () -> Void)?

    @ViewBuilder
    public var body: some View {

        let backButtonColor = colorScheme.airshipResolveColor(
            light: theme.backButtonColor,
            dark: theme.backButtonColorDark
        )

        Button(action: {
            self.dismissAction?()
        }) {
            Image(systemName: "chevron.backward")
                .scaleEffect(0.68)
                .font(Font.title.weight(.medium))
                .foregroundColor(backButtonColor)
        }
    }
}
