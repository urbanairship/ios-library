/* Copyright Airship and Contributors */

import Foundation

struct ThomasConstrainedSize: ThomasSerailizable {
    var minWidth: ThomasSizeConstraint?
    var width: ThomasSizeConstraint
    var maxWidth: ThomasSizeConstraint?
    var minHeight: ThomasSizeConstraint?
    var height: ThomasSizeConstraint
    var maxHeight: ThomasSizeConstraint?

    private enum CodingKeys: String, CodingKey {
        case minWidth = "min_width"
        case width
        case maxWidth = "max_width"
        case minHeight = "min_height"
        case height
        case maxHeight = "max_height"
    }
}
