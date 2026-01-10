/* Copyright Airship and Contributors */

import Foundation

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
