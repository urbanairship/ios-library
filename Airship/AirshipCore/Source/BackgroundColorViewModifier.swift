/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct BackgroundColorViewModifier: ViewModifier {
    let color: ThomasColor
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content.background(color.toColor(colorScheme))
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
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

