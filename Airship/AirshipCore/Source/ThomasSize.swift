/* Copyright Airship and Contributors */

import Foundation

struct ThomasSize: Codable, Equatable, Sendable {
    var width: ThomasSizeConstraint
    var height: ThomasSizeConstraint
    var aspectRatio: Double?

    enum CodingKeys: String, CodingKey {
        case width
        case height
        case aspectRatio = "aspect_ratio"
    }
}
