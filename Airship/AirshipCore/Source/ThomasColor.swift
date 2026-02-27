/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

struct ThomasColor: ThomasSerializable {
    let defaultColor: HexColor
    let selectors: [Selector]?

    enum CodingKeys: String, CodingKey {
        case defaultColor = "default"
        case selectors
    }

    struct HexColor: ThomasSerializable {
        let type: String = "hex"
        var hex: String
        var alpha: Double?

        enum CodingKeys: String, CodingKey {
            case type
            case hex
            case alpha
        }
    }

    struct Selector: ThomasSerializable {
        let darkMode: Bool?
        let platform: ThomasPlatform?
        let color: HexColor

        enum CodingKeys: String, CodingKey {
            case platform
            case darkMode = "dark_mode"
            case color
        }
    }
}
extension ThomasColor.HexColor {
    func toColor() -> Color {
        // Use the new AirshipColor resolver instead of AirshipColorUtils
        let color = AirshipColor.resolveColor(self.hex)
        let alpha = self.alpha ?? 1.0

        // Combine the hex color with the explicit alpha multiplier
        let finalColor = color.opacity(alpha)

        /// Clear needs to be replaced by tappable clear to prevent SwiftUI from passing through tap events
        /// Note: We check if the resulting alpha is 0 (either from hex or explicit alpha)
        if alpha == 0 || color == .clear {
            return ThomasConstants.tappableClearColor
        }

        return finalColor
    }
}

extension ThomasColor {
    func toColor(_ colorScheme: ColorScheme) -> Color {
        let isDarkMode = colorScheme == .dark

        for selector in selectors ?? [] {
            // Platform filtering
            if let platform = selector.platform {
                #if os(macOS)
                if platform != .macOS { continue }
                #else
                if platform != .ios { continue }
                #endif
            }

            // Dark mode filtering
            if let selectorDarkMode = selector.darkMode, isDarkMode != selectorDarkMode {
                continue
            }

            return selector.color.toColor()
        }

        // Fallback to default if no selectors matched
        return defaultColor.toColor()
    }
}


