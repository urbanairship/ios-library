/* Copyright Airship and Contributors */

import Foundation

struct ThomasIconInfo: ThomasSerailizable {
    let type: String = "icon"
    var icon: Icon
    var color: ThomasColor
    var scale: Double?

    enum Icon: String, ThomasSerailizable {
        case close
        case checkmark
        case forwardArrow = "forward_arrow"
        case backArrow = "back_arrow"
    }

    enum CodingKeys: String, CodingKey {
        case icon
        case color
        case scale
        case type
    }
}
