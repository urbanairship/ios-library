/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

struct TextTheme: Equatable {
    var letterSpacing: CGFloat
    var lineSpacing: CGFloat
    var additionalPadding: EdgeInsets

    init(letterSpacing: CGFloat, lineSpacing: CGFloat, additionalPadding: EdgeInsets) {
        self.letterSpacing = letterSpacing
        self.lineSpacing = lineSpacing
        self.additionalPadding = additionalPadding
    }

    init(themeOverride:TextThemeOverride, defaults:TextTheme) {
        self.letterSpacing = themeOverride.letterSpacing.flatMap(CGFloat.init) ?? defaults.letterSpacing
        self.lineSpacing = themeOverride.lineSpacing.flatMap(CGFloat.init) ?? defaults.lineSpacing
        self.additionalPadding = themeOverride.additionalPadding.flatMap { EdgeInsets(themeOverride: $0, defaults: defaults.additionalPadding) } ?? defaults.additionalPadding
    }
}

struct TextThemeOverride: Decodable {
    var letterSpacing: Int?
    var lineSpacing: Int?
    var additionalPadding: EdgeInsetsThemeOverride?

    init(letterSpacing: Int? = nil, lineSpacing: Int? = nil, additionalPadding: EdgeInsetsThemeOverride? = nil) {
        self.letterSpacing = letterSpacing
        self.lineSpacing = lineSpacing
        self.additionalPadding = additionalPadding
    }
}
