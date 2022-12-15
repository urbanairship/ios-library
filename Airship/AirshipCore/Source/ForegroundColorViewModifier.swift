/* Copyright Airship and Contributors */

import Foundation
import SwiftUI


struct ForegroundColorViewModifier: ViewModifier {
    let color: ThomasColor
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content.foregroundColor(color.toColor(colorScheme))
    }
}


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
