/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

extension EdgeInsets {
    init(themeOverride:EdgeInsetsThemeOverride, defaults:EdgeInsets) {
        var t: CGFloat = defaults.top
        var l: CGFloat = defaults.leading
        var tr: CGFloat = defaults.trailing
        var b: CGFloat = defaults.bottom

        if let overrideTop = themeOverride.top {
            t = CGFloat(overrideTop)
        }

        if let overrideLeading = themeOverride.leading {
            l = CGFloat(overrideLeading)
        }

        if let overrideTrailing = themeOverride.trailing {
            tr = CGFloat(overrideTrailing)
        }

        if let overrideBottom = themeOverride.bottom {
            b = CGFloat(overrideBottom)
        }

        self = EdgeInsets(top: t, leading: l, bottom: b, trailing: tr)
    }
}

struct EdgeInsetsThemeOverride: Decodable {
    var top: Int?
    var leading: Int?
    var trailing: Int?
    var bottom: Int?
}
