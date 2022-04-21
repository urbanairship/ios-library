/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct BorderViewModifier: ViewModifier {
    let border: Border
    @Environment(\.colorScheme) var colorScheme
    
    @ViewBuilder
    func body(content: Content) -> some View {
        if let color = border.strokeColor?.toColor(colorScheme), let width = border.strokeWidth {
            if let cornerRadius = border.radius, cornerRadius > 0 {
                content.overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(color, lineWidth: width)
                ).clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                content.border(color, width: width)
            }
        } else if let cornerRadius = border.radius, cornerRadius > 0 {
            content.clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            content
        }
    }
}


@available(iOS 13.0.0, tvOS 13.0, *)
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

