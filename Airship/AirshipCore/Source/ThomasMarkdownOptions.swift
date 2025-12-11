/* Copyright Airship and Contributors */

import Foundation

struct ThomasMarkDownOptions: ThomasSerializable {
    var disabled: Bool?
    var appearance: Appearance?

    struct Appearance: ThomasSerializable {
        var anchor: Anchor?
        var highlight: Highlight?

        struct Highlight: ThomasSerializable {
            var color: ThomasColor?
            var cornerRadius: Double?

            enum CodingKeys: String, CodingKey {
                case color
                case cornerRadius = "corner_radius"
            }
        }

        struct Anchor: ThomasSerializable {
            var color: ThomasColor?
            // Currently we only support underlined styles
            var styles: [ThomasTextAppearance.TextStyle]?
        }
    }
}
