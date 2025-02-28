/* Copyright Airship and Contributors */

import Foundation
import SwiftUI


struct BackgroundViewModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var state: ThomasState

    var backgroundColor: ThomasColor?
    var backgroundColorOverrides: [ThomasPropertyOverride<ThomasColor>]?
    var border: ThomasBorder?
    var borderOverrides: [ThomasPropertyOverride<ThomasBorder>]?
    var shadow: ThomasShadow?

    func body(content: Content) -> some View {
        let border = ThomasPropertyOverride<ThomasBorder>.resolveOptional(
            state: self.state,
            overrides: self.borderOverrides,
            defaultValue: self.border
        )

        let backgroundColor = ThomasPropertyOverride<ThomasColor>.resolveOptional(
            state: self.state,
            overrides: self.backgroundColorOverrides,
            defaultValue: self.backgroundColor
        )

        content
            .clipContent(border: border)
            .applyPadding(padding: border?.strokeWidth)
            .applyBackground(color: backgroundColor, border: border, colorScheme: colorScheme)
            .applyShadow(shadow, border: border, colorScheme: colorScheme)
            .contentShape(.rect(cornerRadius: border?.radius ?? 0, style: .continuous))
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
    func applyShadow(_ shadow: ThomasShadow?, border: ThomasBorder?, colorScheme: ColorScheme) -> some View {
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
        border: ThomasBorder?,
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

fileprivate extension ThomasBorder {
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
    func thomasBackground(
        color: ThomasColor? = nil,
        colorOverrides: [ThomasPropertyOverride<ThomasColor>]? = nil,
        border: ThomasBorder? = nil,
        borderOverrides: [ThomasPropertyOverride<ThomasBorder>]? = nil,
        shadow: ThomasShadow? = nil
    ) -> some View {
        if border != nil || shadow != nil || color != nil || borderOverrides?.isEmpty == false || colorOverrides?.isEmpty == false {
            self.modifier(
                BackgroundViewModifier(
                    backgroundColor: color,
                    backgroundColorOverrides: colorOverrides,
                    border: border,
                    borderOverrides: borderOverrides,
                    shadow: shadow
                )
            )
        } else {
            self
        }
    }

    @ViewBuilder
    fileprivate func clipContent(
        border: ThomasBorder?
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
