/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Capped at the separable blend modes -- the ones Android can draw without a
/// custom shader -- so a scene renders the same on every platform.
enum ThomasBlendMode: String, ThomasSerializable {
    case normal
    case multiply
    case screen
    case overlay
    case darken
    case lighten
    case colorDodge = "color_dodge"
    case colorBurn = "color_burn"
    case hardLight = "hard_light"
    case softLight = "soft_light"
    case difference
    case exclusion
}

extension ThomasBlendMode {
    var swiftUIBlendMode: BlendMode {
        switch self {
        case .normal: .normal
        case .multiply: .multiply
        case .screen: .screen
        case .overlay: .overlay
        case .darken: .darken
        case .lighten: .lighten
        case .colorDodge: .colorDodge
        case .colorBurn: .colorBurn
        case .hardLight: .hardLight
        case .softLight: .softLight
        case .difference: .difference
        case .exclusion: .exclusion
        }
    }
}
