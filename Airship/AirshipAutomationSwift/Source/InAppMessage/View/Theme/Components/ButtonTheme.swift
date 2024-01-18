/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

struct ButtonTheme: Equatable {
    var buttonHeight: CGFloat
    var stackedButtonSpacing: CGFloat
    var separatedButtonSpacing: CGFloat
    var additionalPadding: EdgeInsets

    init(themeOverride:ButtonThemeOverride, defaults:ButtonTheme) {
        self.buttonHeight = themeOverride.buttonHeight.flatMap(CGFloat.init) ?? defaults.buttonHeight
        self.stackedButtonSpacing = themeOverride.stackedButtonSpacing.flatMap(CGFloat.init) ?? defaults.stackedButtonSpacing
        self.separatedButtonSpacing = themeOverride.separatedButtonSpacing.flatMap(CGFloat.init) ?? defaults.separatedButtonSpacing
        self.additionalPadding = themeOverride.additionalPadding.map { EdgeInsets(themeOverride: $0, defaults: defaults.additionalPadding) } ?? defaults.additionalPadding
    }

    init(buttonHeight: CGFloat, stackedButtonSpacing: CGFloat, separatedButtonSpacing: CGFloat, additionalPadding: EdgeInsets) {
        self.buttonHeight = buttonHeight
        self.stackedButtonSpacing = stackedButtonSpacing
        self.separatedButtonSpacing = separatedButtonSpacing
        self.additionalPadding = additionalPadding
    }
}

struct ButtonThemeOverride: Decodable {
    var buttonHeight: Int?
    var stackedButtonSpacing: Int?
    var separatedButtonSpacing: Int?
    var additionalPadding: EdgeInsetsThemeOverride?

    init(buttonHeight: Int, stackedButtonSpacing: Int, separatedButtonSpacing: Int, additionalPadding: EdgeInsetsThemeOverride) {
        self.buttonHeight = buttonHeight
        self.stackedButtonSpacing = stackedButtonSpacing
        self.separatedButtonSpacing = separatedButtonSpacing
        self.additionalPadding = additionalPadding
    }
}
