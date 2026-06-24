/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

struct ThomasMediaUrlSelector: ThomasSerializable {
    var platform: ThomasPlatform?
    var darkMode: Bool?
    var url: String

    private enum CodingKeys: String, CodingKey {
        case platform
        case darkMode = "dark_mode"
        case url
    }
}

extension Array where Element == ThomasMediaUrlSelector {
    func resolve(colorScheme: ColorScheme) -> String? {
        let isDarkMode = colorScheme == .dark
        for selector in self {
            if let platform = selector.platform, platform != .ios { continue }
            if let selectorDarkMode = selector.darkMode, isDarkMode != selectorDarkMode { continue }
            return selector.url
        }
        return nil
    }
}
