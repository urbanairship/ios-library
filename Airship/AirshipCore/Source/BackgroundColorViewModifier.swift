/* Copyright Airship and Contributors */

import Foundation
import SwiftUI


struct BackgroundColorViewModifier: ViewModifier {
    let color: ThomasColor
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content.background(color.toColor(colorScheme))
    }
}


extension View {
    @ViewBuilder
    func background(_ color: ThomasColor?) -> some View {
        if let color = color {
            self.modifier(BackgroundColorViewModifier(color: color))
        } else {
            self
        }
    }
}
