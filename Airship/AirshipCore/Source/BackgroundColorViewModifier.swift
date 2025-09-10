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

        let innerCornerRadii = CustomCornerRadii(innerRadiiFor: resolvedBorder)

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
                CustomRoundedRectangle(
                    cornerRadii: innerCornerRadii,
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

    @ViewBuilder
    func clipContent(
        border: ThomasBorder?
    ) -> some View {
        if let cornerRadius = border?.maxRadius,
           let width = border?.strokeWidth,
           cornerRadius > width
        {
            let cornerRadii = CustomCornerRadii(innerRadiiFor: border)
            ZStack {
                let shape = CustomRoundedRectangle(
                    cornerRadii: cornerRadii,
                    style: .continuous)
                self.clipShape(shape)
            }
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

fileprivate extension ThomasBorder {
    var borderShape: CustomRoundedRectangle? {
        let cornerRadii = CustomCornerRadii(outerRadiiFor: self)

        return CustomRoundedRectangle(
            cornerRadii: cornerRadii,
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

struct CustomCornerRadii: Equatable, Animatable {
    var topLeading: CGFloat
    var topTrailing: CGFloat
    var bottomLeading: CGFloat
    var bottomTrailing: CGFloat

    /// Initializes CustomCornerRadii representing the INNER radii
    /// calculated from a ThomasBorder, subtracting the stroke width.
    init(innerRadiiFor border: ThomasBorder?) {
        // Use guard let for safe unwrapping
        guard let border = border else {
            // If border is nil, initialize with all zeros
            self.init(topLeading: 0, topTrailing: 0, bottomLeading: 0, bottomTrailing: 0)
            return
        }

        // Convert properties to CGFloat for calculations
        let strokeWidth = CGFloat(border.strokeWidth ?? 0.0)

        if let corners = border.cornerRadius {
            // Per-corner radii defined, calculate inner values using max(0, ...)
            self.init( // Call the memberwise initializer
                topLeading: max(0, CGFloat(corners.topLeft ?? 0.0) - strokeWidth),
                topTrailing: max(0, CGFloat(corners.topRight ?? 0.0) - strokeWidth),
                bottomLeading: max(0, CGFloat(corners.bottomLeft ?? 0.0) - strokeWidth),
                bottomTrailing: max(0, CGFloat(corners.bottomRight ?? 0.0) - strokeWidth)
            )
        } else {
            // Fallback to single radius
            let radius = CGFloat(border.radius ?? 0.0)
            let innerRadius = max(0, radius - strokeWidth) // Ensure non-negative
            // Call the memberwise initializer with the single inner radius
            self.init(
                topLeading: innerRadius,
                topTrailing: innerRadius,
                bottomLeading: innerRadius,
                bottomTrailing: innerRadius
            )
        }
    }

    init(outerRadiiFor border: ThomasBorder?) {
        guard let border = border else {
            self.init(topLeading: 0, topTrailing: 0, bottomLeading: 0, bottomTrailing: 0)
            return
        }

        if let corners = border.cornerRadius {
            self.init(
                topLeading: CGFloat(corners.topLeft ?? 0.0),
                topTrailing: CGFloat(corners.topRight ?? 0.0),
                bottomLeading: CGFloat(corners.bottomLeft ?? 0.0),
                bottomTrailing: CGFloat(corners.bottomRight ?? 0.0)
            )
        } else {
            let radius = CGFloat(border.radius ?? 0.0)
            self.init(
                topLeading: radius,
                topTrailing: radius,
                bottomLeading: radius,
                bottomTrailing: radius
            )
        }
    }

    init(topLeading: CGFloat = 0,
                 topTrailing: CGFloat = 0,
                 bottomLeading: CGFloat = 0,
                 bottomTrailing: CGFloat = 0
    ) {
        self.topLeading = topLeading
        self.topTrailing = topTrailing
        self.bottomLeading = bottomLeading
        self.bottomTrailing = bottomTrailing
    }

    var animatableData: AnimatablePair<
        AnimatablePair<CGFloat, CGFloat>,
        AnimatablePair<CGFloat, CGFloat>
    > {
        get {
            AnimatablePair(
                AnimatablePair(topLeading, bottomLeading),
                AnimatablePair(bottomTrailing, topTrailing)
            )
        }
        set {
            topLeading = newValue.first.first
            bottomLeading = newValue.first.second
            bottomTrailing = newValue.second.first
            topTrailing = newValue.second.second
        }
    }
}

struct CustomRoundedRectangle: InsettableShape {
    let cornerRadii: CustomCornerRadii
    let style: RoundedCornerStyle
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let insetRect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        return UnevenRoundedRectangle(
            topLeadingRadius: cornerRadii.topLeading,
            bottomLeadingRadius: cornerRadii.bottomLeading,
            bottomTrailingRadius: cornerRadii.bottomTrailing,
            topTrailingRadius: cornerRadii.topTrailing,
            style: .continuous
        ).path(in: insetRect)
    }

    func inset(by amount: CGFloat) -> CustomRoundedRectangle {
        let adjustedRadii = CustomCornerRadii(
            topLeading: max(0, cornerRadii.topLeading - amount),
            topTrailing: max(0, cornerRadii.topTrailing - amount),
            bottomLeading: max(0, cornerRadii.bottomLeading - amount),
            bottomTrailing: max(0, cornerRadii.bottomTrailing - amount)
        )

        return CustomRoundedRectangle(
            cornerRadii: adjustedRadii,
            style: self.style,
            insetAmount: self.insetAmount + amount
        )
    }
}

extension ThomasBorder {
    var maxRadius: Double? {
        if let cornerRadius = self.cornerRadius {
            return [
                cornerRadius.bottomLeft ?? 0,
                cornerRadius.bottomRight ?? 0,
                cornerRadius.topLeft ?? 0,
                cornerRadius.topRight ?? 0,
            ].max()
        } else {
            return self.radius
        }
    }
}
