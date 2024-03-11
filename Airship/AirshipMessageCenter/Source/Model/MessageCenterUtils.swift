/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

extension Color {
    func adaptiveColor(for colorScheme: ColorScheme, darkVariation: Color?) -> Color? {
        if colorScheme == .light {
            return self
        } else {
            /// If user doesn't provide a dark variation, fall back to the named color variation if it exists
            return darkVariation ?? self
        }
    }
}
