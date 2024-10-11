/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

extension Text {

    @ViewBuilder
    func textAppearance(
        _ overrides: PreferenceCenterTheme.TextAppearance?,
        base: PreferenceCenterTheme.TextAppearance? = nil,
        colorScheme: ColorScheme
    ) -> Text {
        let overridesColor = colorScheme.airshipResolveColor(light: overrides?.color, dark: overrides?.colorDark)
        self.font(overrides?.font ?? base?.font)
            .foregroundColor(overridesColor ?? base?.color)
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
