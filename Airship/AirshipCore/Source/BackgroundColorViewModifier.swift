/* Copyright Airship and Contributors */

import Foundation
import SwiftUI


struct BackgroundViewModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var state: ViewState

    var backgroundColor: ThomasColor?
    var backgroundColorOverrides: [ThomasPropertyOverride<ThomasColor>]?
    var border: ThomasBorder?
    var borderOverrides: [ThomasPropertyOverride<ThomasBorder>]?
    var shadow: ThomasShadow?

    func body(content: Content) -> some View {
        let resolvedBorder = ThomasPropertyOverride<ThomasBorder>.resolveOptional(
            state: state,
            overrides: borderOverrides,
            defaultValue: border
        )
        let resolvedBackgroundColor = ThomasPropertyOverride<ThomasColor>.resolveOptional(
            state: state,
            overrides: backgroundColorOverrides,
            defaultValue: backgroundColor
        )

        return content
            .clipContent(border: resolvedBorder)
            .applyPadding(padding: resolvedBorder?.strokeWidth)
            .applyBackground(
                color: resolvedBackgroundColor,
                border: resolvedBorder,
                colorScheme: colorScheme
            )
            .applyShadow(
                shadow,
                border: resolvedBorder,
                colorScheme: colorScheme
            )
            .contentShape(
                RoundedRectangle(
                    cornerRadius: resolvedBorder?.radius ?? 0,
                    style: .continuous
                )
            )
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
        let strokeColor = border?.strokeColor?.toColor(colorScheme) ?? .black
        let bgColor = color?.toColor(colorScheme) ?? .clear

        if let strokeWidth = border?.strokeWidth, strokeWidth > 0 {
            if let borderShape = border?.borderShape {
                self.background(
                    borderShape
                        .strokeBorder(strokeColor, lineWidth: strokeWidth)
                        .background(borderShape.inset(by: strokeWidth).fill(bgColor))
                )
                .clipShape(borderShape)
            } else {
                self.background(
                    Rectangle()
                        .strokeBorder(strokeColor, lineWidth: strokeWidth)
                        .background(Rectangle().inset(by: strokeWidth).fill(bgColor))
                )

            }
        } else if let borderShape = border?.borderShape {
            self.background(bgColor)
                .clipShape(borderShape)
        } else {
            self.background(bgColor)
        }
    }

    @ViewBuilder
    func clipContent(border: ThomasBorder?) -> some View {
        if let width = border?.strokeWidth,
           let cornerRadius = border?.radius,
           cornerRadius > width {
            let shape = RoundedRectangle(
                cornerRadius: cornerRadius - width,
                style: .continuous
            )
            self.clipShape(shape)
        } else {
            self
        }
    }
}

fileprivate extension ThomasShadow {
    var resolvedBoxShadow: ThomasShadow.BoxShadow? {
        selectors?.first {
            $0.platform == nil || $0.platform == .ios
        }?.shadow.boxShadow
    }
}

fileprivate struct CustomRoundedRectangle: InsettableShape {
    let corners: (topLeft: Double, topRight: Double, bottomLeft: Double, bottomRight: Double)
    let style: RoundedCornerStyle
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        /// Center the inset along the path which follows what Apple likes
        let insetRect = rect.insetBy(dx: insetAmount/2, dy: insetAmount/2)
        var path = Path()

        let tl = min(corners.topLeft, min(insetRect.width, insetRect.height) / 2)
        let tr = min(corners.topRight, min(insetRect.width, insetRect.height) / 2)
        let bl = min(corners.bottomLeft, min(insetRect.width, insetRect.height) / 2)
        let br = min(corners.bottomRight, min(insetRect.width, insetRect.height) / 2)

        path.move(to: CGPoint(x: tl + insetRect.minX, y: insetRect.minY))

        // Top edge + top-right corner
        path.addLine(to: CGPoint(x: insetRect.maxX - tr, y: insetRect.minY))
        path.addArc(
            center: CGPoint(x: insetRect.maxX - tr, y: insetRect.minY + tr),
            radius: tr,
            startAngle: Angle(degrees: -90),
            endAngle: Angle(degrees: 0),
            clockwise: false
        )

        // Right edge + bottom-right corner
        path.addLine(to: CGPoint(x: insetRect.maxX, y: insetRect.maxY - br))
        path.addArc(
            center: CGPoint(x: insetRect.maxX - br, y: insetRect.maxY - br),
            radius: br,
            startAngle: Angle(degrees: 0),
            endAngle: Angle(degrees: 90),
            clockwise: false
        )

        // Bottom edge + bottom-left corner
        path.addLine(to: CGPoint(x: insetRect.minX + bl, y: insetRect.maxY))
        path.addArc(
            center: CGPoint(x: insetRect.minX + bl, y: insetRect.maxY - bl),
            radius: bl,
            startAngle: Angle(degrees: 90),
            endAngle: Angle(degrees: 180),
            clockwise: false
        )

        // Left edge + top-left corner
        path.addLine(to: CGPoint(x: insetRect.minX, y: insetRect.minY + tl))
        path.addArc(
            center: CGPoint(x: insetRect.minX + tl, y: insetRect.minY + tl),
            radius: tl,
            startAngle: Angle(degrees: 180),
            endAngle: Angle(degrees: 270),
            clockwise: false
        )

        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> CustomRoundedRectangle {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}

fileprivate extension ThomasBorder {
    var borderShape: CustomRoundedRectangle? {
        let corners = effectiveCornerRadius
        guard corners.topLeft > 0 || corners.topRight > 0 || corners.bottomLeft > 0 || corners.bottomRight > 0 else {
            return nil
        }
        return CustomRoundedRectangle(corners: corners, style: .continuous)
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
        if border != nil ||
            shadow != nil ||
            color != nil ||
            (borderOverrides?.isEmpty == false) ||
            (colorOverrides?.isEmpty == false) {
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
}
