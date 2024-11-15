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
        guard let uiColor = AirshipColorUtils.color(self.hex) else {
            return ThomasConstants.tappableClearColor
        }

        let alpha = self.alpha ?? 1

        let color = Color(uiColor).opacity(alpha)

        /// Clear needs to be replaced by tappable clear to prevent SwiftUI from passing through tap events
        if alpha == 0 {
            return  ThomasConstants.tappableClearColor
        }

        return color
    }

    func toUIColor() -> UIColor {
        let hexColor = hex.trimmingCharacters(
            in: CharacterSet.alphanumerics.inverted
        )
        guard
            let int = Scanner(string: hexColor)
                .scanInt32(
                    representation: .hexadecimal
                )
        else { return UIColor.white }

        let r: Int32
        let g: Int32
        let b: Int32
        switch hexColor.count {
        case 3:
            (r, g, b) = (
                (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17
            )  // RGB (12-bit)
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)  // RGB (24-bit)
        default:
            (r, g, b) = (0, 0, 0)
        }

        return UIColor(
            red: CGFloat(r) / 255.0,
            green: CGFloat(g) / 255.0,
            blue: CGFloat(b) / 255.0,
            alpha: alpha ?? 0
        )
    }
}

extension ThomasColor {
    func toColor(_ colorScheme: ColorScheme) -> Color {
        let darkMode = colorScheme == .dark
        for selector in selectors ?? [] {
            if let platform = selector.platform, platform != .ios {
                continue
            }

            if let selectorDarkMode = selector.darkMode,
                darkMode != selectorDarkMode
            {
                continue
            }

            return selector.color.toColor()
        }

        return defaultColor.toColor()
    }

    func toUIColor(_ colorScheme: ColorScheme) -> UIColor {
        guard #available(iOS 14.0.0, tvOS 14.0.0, *) else {
            let darkMode = colorScheme == .dark
            for selector in selectors ?? [] {
                if let platform = selector.platform, platform != .ios {
                    continue
                }

                if let selectorDarkMode = selector.darkMode,
                    darkMode != selectorDarkMode
                {
                    continue
                }

                return selector.color.toUIColor()
            }

            return defaultColor.toUIColor()
        }
        return UIColor(toColor(colorScheme))
    }
}


