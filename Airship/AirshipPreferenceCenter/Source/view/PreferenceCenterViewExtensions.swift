/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

extension Text {

    @ViewBuilder
    func textAppearance(
        _ overrides: PreferenceCenterTheme.TextAppearance?,
        base: PreferenceCenterTheme.TextAppearance? = nil
    ) -> Text {
        self.font(overrides?.font ?? base?.font)
            .foregroundColor(overrides?.color ?? base?.color)
    }
}

extension View {
    @ViewBuilder
    func toggleStyle(tint: Color?) -> some View {
        if let tint = tint {
            self.toggleStyle(SwitchToggleStyle(tint: tint))
        } else {
            self
        }
    }

    @ViewBuilder
    func optAccessibilityLabel(string: String?) -> some View {
        if let string = string {
            self.accessibilityLabel(string)
        } else {
            self
        }
    }
}
