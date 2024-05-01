/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// For color utils
#if canImport(AirshipCore)
import AirshipCore
#endif

struct ShadowTheme: Equatable {
    var radius: CGFloat
    var xOffset: CGFloat
    var yOffset: CGFloat
    var color: Color

    init(radius: CGFloat,  xOffset: CGFloat, yOffset: CGFloat, color: Color) {
        self.radius = radius
        self.xOffset = xOffset
        self.yOffset = yOffset
        self.color = color
    }

    init(themeOverride: ShadowThemeOverride, defaults: ShadowTheme) {
        self.radius = themeOverride.radius.flatMap(CGFloat.init) ?? defaults.radius
        self.xOffset = themeOverride.xOffset.flatMap(CGFloat.init) ?? defaults.xOffset
        self.yOffset = themeOverride.yOffset.flatMap(CGFloat.init) ?? defaults.yOffset
        self.color = themeOverride.color.flatMap { $0.airshipToColor() } ?? defaults.color
    }
}

struct ShadowThemeOverride: Decodable {
    var radius: Int?
    var xOffset: Int?
    var yOffset: Int?
    var color: String?

    init(radius: Int? = nil, xOffset: Int? = nil, yOffset: Int? = nil, color: String? = nil) {
        self.radius = radius
        self.xOffset = xOffset
        self.yOffset = yOffset
        self.color = color
    }

    enum CodingKeys: String, CodingKey {
        case radius = "radius"
        case xOffset = "xOffset"
        case yOffset = "yOffset"
        case color = "colorHex"
    }
}
