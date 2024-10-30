/* Copyright Airship and Contributors */

import Foundation
import SwiftUI


struct BackgroundViewModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    var color: ThomasColor?
    var border: Border?
    var shadow: ThomasShadow?

    func body(content: Content) -> some View {
        content
            .clipContent(border: border)
            .applyPadding(padding: border?.strokeWidth)
            .applyBackground(color: color, border: border, colorScheme: colorScheme)
            .applyShadow(shadow, border: border, colorScheme: colorScheme)
    }
}

fileprivate extension View {
    @ViewBuilder
    func applyPadding(padding: Double?) -> some View {
        if let padding {
            self.padding(padding)
        } else {
            self
        }
    }

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
    func applyBackground(
        color: ThomasColor?,
        border: Border?,
        colorScheme: ColorScheme
    ) -> some View {
        // Defaults to black to match Android & Web
        let strokeColor: Color = border?.strokeColor?.toColor(colorScheme) ?? .black
        let backgroundColor: Color = color?.toColor(colorScheme) ?? .clear

        if let strokeWidth = border?.strokeWidth, strokeWidth > 0 {
            if let borderShape = border?.borderShape {
                self.background(
                    borderShape
                        .strokeBorder(strokeColor, lineWidth: strokeWidth)
                        .background(borderShape.inset(by: strokeWidth).fill(backgroundColor))
                )
                .clipShape(borderShape)
            } else {
                self.background(
                    Rectangle()
                        .strokeBorder(strokeColor, lineWidth: strokeWidth)
                        .background(Rectangle().inset(by: strokeWidth).fill(backgroundColor))
                )
            }
        } else if let borderShape = border?.borderShape {
            self.background(backgroundColor)
                .clipShape(borderShape)
        } else {
            self.background(backgroundColor)
        }
    }
}

fileprivate extension ThomasShadow {
    var resolvedBoxShadow: ThomasShadow.BoxShadow? {
        self.selectors?.first(
            where: { selector in
                selector.platform == nil || selector.platform == .ios
            }
        )?.shadow.boxShadow
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
    func background(
        color: ThomasColor? = nil,
        border: Border? = nil,
        shadow: ThomasShadow? = nil
    ) -> some View {
        if border != nil || shadow != nil || color != nil {
            self.modifier(
                BackgroundViewModifier(
                    color: color,
                    border: border,
                    shadow: shadow
                )
            )
        } else {
            self
        }
    }

    @ViewBuilder
    fileprivate func clipContent(
        border: Border?
    ) -> some View {
        if let width = border?.strokeWidth,
           let cornerRadius = border?.radius,
           cornerRadius > width
        {
            ZStack {
                let shape = RoundedRectangle(
                    cornerRadius: cornerRadius - width,
                    style: .continuous
                )
                self.clipShape(shape)
            }
        } else {
            self
        }
    }


}
