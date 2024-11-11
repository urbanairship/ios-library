/* Copyright Airship and Contributors */

import Foundation

struct ThomasBorder: Codable, Equatable, Sendable {
    var radius: Double?
    var strokeWidth: Double?
    var strokeColor: ThomasColor?

    enum CodingKeys: String, CodingKey {
        case radius
        case strokeWidth = "stroke_width"
        case strokeColor = "stroke_color"
    }
}
