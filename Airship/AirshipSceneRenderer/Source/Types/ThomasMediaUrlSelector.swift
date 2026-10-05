/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

struct ThomasMediaUrlSelector: ThomasSerializable, ThomasSelectorConditions {
    var platform: ThomasPlatform?
    var darkMode: Bool?
    var windowSize: ThomasWindowSize?
    var orientation: ThomasOrientation?
    var url: String

    private enum CodingKeys: String, CodingKey {
        case platform
        case darkMode = "dark_mode"
        case windowSize = "window_size"
        case orientation
        case url
    }
}

extension Array where Element == ThomasMediaUrlSelector {
    func resolve(_ environment: ThomasSelectorEnvironment) -> String? {
        firstMatch(environment)?.url
    }
}
