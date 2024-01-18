/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

struct MediaTheme: Equatable  {
    var additionalPadding: EdgeInsets

    init(themeOverride: MediaThemeOverride, defaults: MediaTheme) {
        additionalPadding = themeOverride.additionalPadding.map { EdgeInsets(themeOverride: $0, defaults: defaults.additionalPadding) } ?? defaults.additionalPadding
    }

    init(additionalPadding: EdgeInsets) {
        self.additionalPadding = additionalPadding
    }
}

struct MediaThemeOverride: Decodable {
    var additionalPadding: EdgeInsetsThemeOverride?

    enum CodingKeys: String, CodingKey {
        case additionalPadding
    }

    init(additionalPadding: EdgeInsetsThemeOverride) {
        self.additionalPadding = additionalPadding
    }
}
