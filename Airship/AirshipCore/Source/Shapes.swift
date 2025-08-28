/* Copyright Airship and Contributors */


import SwiftUI


struct Shapes {

    @ViewBuilder
    @MainActor
    static func shape(
        info: ThomasShapeInfo,
        constraints: ViewConstraints,
        colorScheme: ColorScheme
    ) -> some View {
        switch info {
        case .ellipse(let info):
            ellipse(
                info: info,
                constraints: constraints,
                colorScheme: colorScheme
            )
        case .rectangle(let info):
            rectangle(
                info: info,
                constraints: constraints,
                colorScheme: colorScheme
            )
        }
    }

    @ViewBuilder
    private static func rectangle(
        colorScheme: ColorScheme,
        border: ThomasBorder?
    ) -> some View {
        let strokeColor = border?.strokeColor?.toColor(colorScheme) ?? Color.clear
        let strokeWidth = border?.strokeWidth ?? 0
        let cornerRadius = border?.radius ?? 0

        if cornerRadius > 0 {
            if strokeWidth > 0 {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(strokeColor, lineWidth: strokeWidth)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.clear)
            }
        } else {
            if strokeWidth > 0 {
                Rectangle()
                    .strokeBorder(strokeColor, lineWidth: strokeWidth)
            } else {
                Rectangle().fill(Color.clear)
            }
        }
    }

    @ViewBuilder
    private static func rectangleBackground(
        border: ThomasBorder?,
        color: Color
    ) -> some View {
        let cornerRadius = border?.radius ?? 0
        if cornerRadius > 0 {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(color)
        } else {
            Rectangle()
                .fill(color)
        }
    }

    @ViewBuilder
    @MainActor
    private static func rectangle(
        info: ThomasShapeInfo.Rectangle,
        constraints: ViewConstraints,
        colorScheme: ColorScheme
    ) -> some View {
        let resolvedColor = info.color?.toColor(colorScheme) ?? Color.clear
        if let border = info.border {
            rectangle(colorScheme: colorScheme, border: border)
                .background(
                    rectangleBackground(border: border, color: resolvedColor)
                )
                .aspectRatio(info.aspectRatio ?? 1, contentMode: .fit)
                .airshipApplyIf(info.scale != nil) { view in
                    view.constraints(
                        scaledConstraints(constraints, scale: info.scale)
                    )
                }
                .constraints(constraints)
        } else {
            Rectangle()
                .fill(resolvedColor)
                .aspectRatio(info.aspectRatio ?? 1, contentMode: .fit)
                .airshipApplyIf(info.scale != nil) { view in
                    view.constraints(
                        scaledConstraints(constraints, scale: info.scale)
                    )
                }
                .constraints(constraints)
        }
    }

    private static func scaledConstraints(
        _ constraints: ViewConstraints,
        scale: Double?
    ) -> ViewConstraints {
        guard let scale = scale else {
            return constraints
        }

        var scaled = constraints
        if let width = scaled.width {
            scaled.width = width * scale
        }
        if let height = scaled.height {
            scaled.height = height * scale
        }
        return scaled
    }

    @ViewBuilder
    private static func ellipse(colorScheme: ColorScheme, border: ThomasBorder?)
        -> some View
    {
        let strokeColor = border?.strokeColor?.toColor(colorScheme)
        let strokeWidth = border?.strokeWidth ?? 0

        if let strokeColor = strokeColor, strokeWidth > 0 {
            Ellipse().strokeBorder(strokeColor, lineWidth: strokeWidth)
        } else {
            Ellipse()
        }
    }

    @ViewBuilder
    @MainActor
    private static func ellipse(
        info: ThomasShapeInfo.Ellipse,
        constraints: ViewConstraints,
        colorScheme: ColorScheme
    ) -> some View {
        let scaled = scaledConstraints(constraints, scale: info.scale)
        let color = info.color?.toColor(colorScheme) ?? Color.clear
        if let border = info.border {
            ellipse(colorScheme: colorScheme, border: border)
                .aspectRatio(info.aspectRatio ?? 1, contentMode: .fit)
                .background(Ellipse().fill(color))
                .airshipApplyIf(info.scale != nil) { view in
                    view.constraints(scaled)
                }
                .constraints(constraints)
        } else {
            Ellipse()
                .fill(color)
                .aspectRatio(info.aspectRatio ?? 1, contentMode: .fit)
                .airshipApplyIf(info.scale != nil) { view in
                    view.constraints(scaled)
                }
                .constraints(constraints)
        }
    }
}
