/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct ForegroundColorViewModifier: ViewModifier {
    let color: ThomasColor
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content.foregroundColor(color.toColor(colorScheme))
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
extension View {
    @ViewBuilder
    func foreground(_ color: ThomasColor?) -> some View {
        if let color = color {
            self.modifier(ForegroundColorViewModifier(color: color))
        } else {
            self
        }
    }
}

