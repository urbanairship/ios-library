/* Copyright Airship and Contributors */

import Foundation

struct ThomasTextAppearance: ThomasSerailizable {
    var color: ThomasColor
    var fontSize: Double
    var alignment: TextAlignement?
    var styles: [TextStyle]?
    var fontFamilies: [String]?
    var placeHolderColor: ThomasColor?

    enum TextStyle: String, ThomasSerailizable {
        case bold
        case italic
        case underlined
    }

    enum TextAlignement: String, ThomasSerailizable {
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
    }
}
