/* Copyright Airship and Contributors */

import Foundation

struct ThomasIconInfo: ThomasSerializable {
    let type: String = "icon"
    var icon: Icon
    var color: ThomasColor
    var scale: Double?

    enum Icon: String, ThomasSerializable {
        case close
        case checkmark
        case forwardArrow = "forward_arrow"
        case backArrow = "back_arrow"
        case exclamationmarkCircleFill = "exclamationmark_circle_fill"
        case progressSpinner = "progress_spinner"
        case asterisk
    }

    enum CodingKeys: String, CodingKey {
        case icon
        case color
        case scale
        case type
    }
}
