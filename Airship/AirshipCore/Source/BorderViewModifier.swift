/* Copyright Airship and Contributors */

import Foundation
import SwiftUI


struct BorderViewModifier: ViewModifier {
    let border: Border
    @Environment(\.colorScheme) var colorScheme

    @ViewBuilder
    func body(content: Content) -> some View {
        if let width = border.strokeWidth {
            // Defaults to black to match Android & Web
            let color = border.strokeColor?.toColor(colorScheme) ?? .black
            if let cornerRadius = border.radius, cornerRadius > 0 {
                content.overlay(
                    RoundedRectangle(
                        cornerRadius: cornerRadius,
                        style: .continuous
                    )
                    .strokeBorder(color, lineWidth: width)
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: cornerRadius,
                        style: .continuous
                    )
                )
            } else {
                content.border(color, width: width)
            }
        } else if let cornerRadius = border.radius, cornerRadius > 0 {
            content.clipShape(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        } else {
            content
        }
    }
}


extension View {
    @ViewBuilder
    func border(_ border: Border?) -> some View {
        if let border = border {
            self.modifier(BorderViewModifier(border: border))
        } else {
            self
        }
    }
}
