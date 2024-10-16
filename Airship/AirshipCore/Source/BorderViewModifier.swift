/* Copyright Airship and Contributors */

import Foundation
import SwiftUI


struct BorderViewModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    var border: Border?
    var shadow: ThomasShadow?

    func body(content: Content) -> some View {
        return content
            .applyBorder(border, colorScheme: colorScheme)
            .applyShadow(shadow, border: border, colorScheme: colorScheme)
    }
}

fileprivate extension View {
    @ViewBuilder
    func applyShadow(_ shadow: ThomasShadow?, border: Border?, colorScheme: ColorScheme) -> some View {
        if let boxShadow = shadow?.resolvedBoxShadow {
            if let borderShape = border?.borderShape {
                self.background(
                    ZStack {
                        borderShape
                            .fill(boxShadow.color.toColor(colorScheme))
                            .padding(.all, -boxShadow.radius/2.0)
                            .blur(radius: boxShadow.blurRadius, opaque: false)
                            .offset(
                                x: boxShadow.offsetX ?? 0,
                                y: boxShadow.offsetY ?? 0
                            )
                        borderShape.blendMode(.destinationOut)
                    }
                        .compositingGroup()
                        .allowsHitTesting(false)
                )
            } else {
                self.background(
                    ZStack {
                        Rectangle()
                            .fill(boxShadow.color.toColor(colorScheme))
                            .padding(.all, -boxShadow.radius/2.0)
                            .blur(radius: boxShadow.blurRadius, opaque: false)
                            .offset(
                                x: boxShadow.offsetX ?? 0,
                                y: boxShadow.offsetY ?? 0
                            )
                        Rectangle().blendMode(.destinationOut)
                    }
                        .compositingGroup()
                        .allowsHitTesting(false)
                 )
            }
        } else {
            self
        }
    }

    @ViewBuilder
    func applyBorder(_ border: Border?, colorScheme: ColorScheme) -> some View {
        if let strokeWidth = border?.strokeWidth, strokeWidth > 0 {
            // Defaults to black to match Android & Web
            let color = border?.strokeColor?.toColor(colorScheme) ?? .black
            if let borderShape = border?.borderShape {
                self.overlay(
                    borderShape.strokeBorder(color, lineWidth: strokeWidth)
                )
                .clipShape(borderShape)
            } else {
                self.border(color, width: strokeWidth)
            }
        } else if let borderShape = border?.borderShape {
            self.clipShape(borderShape)
        } else {
            self
        }
    }
}

fileprivate extension ThomasShadow {
    var resolvedBoxShadow: ThomasShadow.BoxShadow? {
        let selected = self.selectors?.first(
            where: { selector in
                selector.platform == nil || selector.platform == .ios
            }
        )

        guard let selected else {
            return self.defaultShadow.boxShadow
        }
        return selected.shadow.boxShadow
    }
}

fileprivate extension Border {
    var borderShape: RoundedRectangle? {
        guard let cornerRadius = self.radius, cornerRadius > 0 else {
            return nil
        }

        return RoundedRectangle(
            cornerRadius: cornerRadius,
            style: .continuous
        )
    }
}

extension View {
    @ViewBuilder
    func border(_ border: Border?, shadow: ThomasShadow? = nil) -> some View {
        if border != nil || shadow != nil {
            self.modifier(BorderViewModifier(border: border, shadow: shadow))
        } else {
            self
        }
    }
}
