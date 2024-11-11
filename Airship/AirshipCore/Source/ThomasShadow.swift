/* Copyright Airship and Contributors */

import Foundation

struct ThomasShadow: ThomasSerailizable {
    let selectors: [Selector]?

    enum CodingKeys: String, CodingKey {
        case selectors
    }

    struct Selector: ThomasSerailizable {
        var shadow: Shadow
        var platform: ThomasPlatform?

        private enum CodingKeys: String, CodingKey {
            case platform
            case shadow
        }
    }

    struct Shadow: ThomasSerailizable {
        var boxShadow: BoxShadow?

        private enum CodingKeys: String, CodingKey {
            case boxShadow = "box_shadow"
        }
    }

    struct BoxShadow: ThomasSerailizable {
        var color: ThomasColor
        var radius: Double
        var blurRadius: Double
        var offsetY: Double?
        var offsetX: Double?

        private enum CodingKeys: String, CodingKey {
            case color
            case radius
            case blurRadius = "blur_radius"
            case offsetY = "offset_y"
            case offsetX = "offset_x"
        }
    }
}
