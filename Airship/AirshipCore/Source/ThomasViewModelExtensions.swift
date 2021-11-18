/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
extension HexColor {
    func toColor() -> Color {
        guard let uiColor = ColorUtils.color(self.hex) else {
            return Color.clear
        }
        
        let alpha = self.alpha ?? 1
        return Color(uiColor).opacity(alpha)
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
extension ThomasColor {
    func toColor(_ colorScheme: ColorScheme) -> Color {
        let darkMode = colorScheme == .dark
        for selector in selectors ?? [] {
            if let platform = selector.platform, platform != .ios {
                continue
            }
            
            if let selectorDarkMode = selector.darkMode, darkMode != selectorDarkMode {
                continue
            }
            
            return selector.color.toColor()
        }
        
        return defaultColor.toColor()
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
    static let clear = HexColor(hex: "#000000", alpha: 0.00001)
}

