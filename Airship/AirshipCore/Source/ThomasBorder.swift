/* Copyright Airship and Contributors */

import Foundation

struct ThomasBorder: Codable, Equatable, Sendable {
    struct CornerRadius: Codable, Equatable, Sendable {
        var topLeft: Double?
        var topRight: Double?
        var bottomLeft: Double?
        var bottomRight: Double?

        enum CodingKeys: String, CodingKey {
            case topLeft = "top_left"
            case topRight = "top_right"
            case bottomLeft = "bottom_left"
            case bottomRight = "bottom_right"
        }
    }

    var radius: Double?
    var cornerRadius: CornerRadius?
    var strokeWidth: Double?
    var strokeColor: ThomasColor?

    enum CodingKeys: String, CodingKey {
        case radius
        case cornerRadius = "corner_radius"
        case strokeWidth = "stroke_width"
        case strokeColor = "stroke_color"
    }
}

extension ThomasBorder {
    var effectiveCornerRadius: (topLeft: Double, topRight: Double, bottomLeft: Double, bottomRight: Double) {
        let defaultRadius = radius ?? 0
        return (
            topLeft: cornerRadius?.topLeft ?? defaultRadius,
            topRight: cornerRadius?.topRight ?? defaultRadius,
            bottomLeft: cornerRadius?.bottomLeft ?? defaultRadius,
            bottomRight: cornerRadius?.bottomRight ?? defaultRadius
        )
    }
}
