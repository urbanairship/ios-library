/* Copyright Airship and Contributors */


import SwiftUI

extension View {
    @ViewBuilder
    func textAppearance(
        _ overrides: PreferenceCenterTheme.TextAppearance?,
        base: PreferenceCenterTheme.TextAppearance? = nil,
        colorScheme: ColorScheme
    ) -> some View {
        let overridesColor = colorScheme.airshipResolveColor(light: overrides?.color, dark: overrides?.colorDark)
        self.font(overrides?.font ?? base?.font)
            .foregroundColor(overridesColor ?? base?.color ?? AirshipSystemColors.label)
    }

    @ViewBuilder
    func toggleStyle(tint: Color?) -> some View {
        if let tint = tint {
            #if os(tvOS)
            self.tint(tint)
            #else
            self.toggleStyle(SwitchToggleStyle(tint: tint))
            #endif
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
