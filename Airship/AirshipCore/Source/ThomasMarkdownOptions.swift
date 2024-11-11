/* Copyright Airship and Contributors */

import Foundation

struct ThomasMarkDownOptions: ThomasSerailizable {
    var disabled: Bool?
    var appearance: Appearance?

    struct Appearance: ThomasSerailizable {
        var anchor: Anchor?

        struct Anchor: ThomasSerailizable {
            var color: ThomasColor?
            // Currently we only support underlined styles
            var styles: [ThomasTextAppearance.TextStyle]?
        }
    }
}
