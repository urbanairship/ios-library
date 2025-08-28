/* Copyright Airship and Contributors */



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
        case asteriskCicleFill = "asterisk_circle_fill"
        case star = "star"
        case starFill = "star_fill"
        case heart = "heart"
        case heartFill = "heart_fill"
    }

    enum CodingKeys: String, CodingKey {
        case icon
        case color
        case scale
        case type
    }
}
