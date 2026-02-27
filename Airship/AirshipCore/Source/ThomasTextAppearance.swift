/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

struct ThomasTextAppearance: ThomasSerializable {
    var color: ThomasColor
    var fontSize: Double
    var alignment: TextAlignement?
    var styles: [TextStyle]?
    var fontFamilies: [String]?
    var placeHolderColor: ThomasColor?
    var lineHeightMultiplier: Double?
    var kerning: Double?
    var fontWeight: Double?

    enum TextStyle: String, ThomasSerializable {
        case bold
        case italic
        case underlined
    }

    enum TextAlignement: String, ThomasSerializable {
        case start
        case end
        case center
    }
    
    enum CodingKeys: String, CodingKey {
        case color
        case fontSize = "font_size"
        case alignment
        case styles
        case fontFamilies = "font_families"
        case placeHolderColor = "place_holder_color"
        case lineHeightMultiplier = "line_height_multiplier"
        case fontWeight = "font_weight"
        case kerning
    }
}

extension ThomasTextAppearance {

    /// Resolves the SwiftUI Font using the AirshipFont system
    @MainActor
    var font: Font {
        return AirshipFont.resolveFont(
            size: self.fontSize,
            families: self.fontFamilies,
            weight: self.fontWeight,
            isItalic: self.styles?.contains(.italic) ?? false,
            isBold: self.styles?.contains(.bold) ?? false
        )
    }

    /// Resolves the Native Font (UIFont/NSFont) using the AirshipFont system
    @MainActor
    var nativeFont: AirshipNativeFont {
        return AirshipFont.resolveNativeFont(
            size: self.fontSize,
            families: self.fontFamilies,
            weight: self.fontWeight,
            isItalic: self.styles?.contains(.italic) ?? false,
            isBold: self.styles?.contains(.bold) ?? false
        )
    }

    /// Returns the scaled font size based on platform logic
    var scaledFontSize: Double {
        return AirshipFont.scaledSize(self.fontSize)
    }

    /// Helper to determine if a specific text style is present
    func hasStyle(_ style: ThomasTextAppearance.TextStyle) -> Bool {
        return self.styles?.contains(style) ?? false
    }
}
