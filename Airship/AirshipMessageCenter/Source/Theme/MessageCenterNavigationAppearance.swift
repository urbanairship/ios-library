/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#endif

import SwiftUI

/// Resolves the effective navigation styling by prioritizing detected
/// system appearance over the Airship theme.
internal struct MessageCenterNavigationAppearance {
    let theme: MessageCenterTheme
    let colorScheme: ColorScheme

    // Detected system properties (optional)
    var barTintColor: Color?
    var barBackgroundColor: Color?
    var titleColor: Color?
    var titleFont: Font?

    /// Initializer with optional detected properties.
    init(
        theme: MessageCenterTheme,
        colorScheme: ColorScheme,
        barTintColor: Color? = nil,
        barBackgroundColor: Color? = nil,
        titleColor: Color? = nil,
        titleFont: Font? = nil
    ) {
        self.theme = theme
        self.colorScheme = colorScheme
        self.barTintColor = barTintColor
        self.barBackgroundColor = barBackgroundColor
        self.titleColor = titleColor
        self.titleFont = titleFont
    }

    private func resolve(light: Color?, dark: Color?, detected: Color?) -> Color? {
        colorScheme.airshipResolveColor(light: light, dark: dark) ?? detected
    }

    var backButtonColor: Color? {
        resolve(
            light: theme.backButtonColor,
            dark: theme.backButtonColorDark,
            detected: barTintColor)
    }

    var deleteButtonColor: Color? {
        resolve(
            light: theme.deleteButtonTitleColor,
            dark: theme.deleteButtonTitleColorDark,
            detected: barTintColor
        )
    }

    func editButtonColor(isEditing: Bool) -> Color? {
        if isEditing {
            return resolve(
                light: theme.cancelButtonTitleColor,
                dark: theme.cancelButtonTitleColorDark,
                detected: barTintColor
            )
        } else {
            return resolve(
                light: theme.editButtonTitleColor,
                dark: theme.editButtonTitleColorDark,
                detected: barTintColor
            )
        }
    }

    var effectiveBarBackgroundColor: Color? {
        resolve(
            light: theme.messageListContainerBackgroundColor,
            dark: theme.messageListContainerBackgroundColorDark,
            detected: barBackgroundColor
        )
    }
}
