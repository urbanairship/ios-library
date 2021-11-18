/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
extension HexColor {
    func toColor() -> Color {
        guard let uiColor = ColorUtils.color(self.hexColor) else {
            return Color.clear
        }
        
        let alpha = self.alpha ?? 1
        return Color(uiColor).opacity(alpha)
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
extension VerticalPosition {
    func toAlignment() -> VerticalAlignment {
        switch (self) {
        case .top: return VerticalAlignment.top
        case .center: return VerticalAlignment.center
        case .bottom: return VerticalAlignment.bottom
        }
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
extension HorizontalPosition {
    func toAlignment() -> HorizontalAlignment {
        switch (self) {
        case .start: return HorizontalAlignment.leading
        case .center: return HorizontalAlignment.center
        case .end: return HorizontalAlignment.trailing
        }
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
extension HexColor {
    static let clear = HexColor(hexColor: "#000000", alpha: 0.00001)
}

