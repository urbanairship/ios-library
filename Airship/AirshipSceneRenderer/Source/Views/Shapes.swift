/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
@_spi(AirshipInternal) import AirshipBasement


struct Shapes {

    @MainActor
    static func shape(
        info: ThomasShapeInfo,
        constraints: ViewConstraints,
        selectorEnvironment: ThomasSelectorEnvironment
    ) -> some View {
        ShapeContent(
            info: info,
            constraints: constraints,
            selectorEnvironment: selectorEnvironment
        )
    }

    @ViewBuilder
    private static func rectangle(
        selectorEnvironment: ThomasSelectorEnvironment,
        border: ThomasBorder?
    ) -> some View {
        let strokeColor = border?.strokeColor?.toColor(selectorEnvironment) ?? Color.clear
        let strokeWidth = border?.strokeWidth ?? 0
        let cornerRadius = border?.maxRadius ?? 0

        if cornerRadius > 0 {
            let cornerRadii = CustomCornerRadii(outerRadiiFor: border)
            let shape = CustomRoundedRectangle(cornerRadii: cornerRadii, style: .continuous)
            if strokeWidth > 0 {
                shape.strokeBorder(strokeColor, lineWidth: strokeWidth)
            } else {
                shape.fill(Color.clear)
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
        let cornerRadius = border?.maxRadius ?? 0
        if cornerRadius > 0 {
            let cornerRadii = CustomCornerRadii(outerRadiiFor: border)
            CustomRoundedRectangle(cornerRadii: cornerRadii, style: .continuous)
                .fill(color)
        } else {
            Rectangle()
                .fill(color)
        }
    }

    @ViewBuilder
    @MainActor
    fileprivate static func rectangle(
        info: ThomasShapeInfo.Rectangle,
        constraints: ViewConstraints,
        selectorEnvironment: ThomasSelectorEnvironment
    ) -> some View {
        let resolvedColor = info.color?.toColor(selectorEnvironment) ?? Color.clear
        if let border = info.border {
            rectangle(selectorEnvironment: selectorEnvironment, border: border)
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
    private static func ellipse(selectorEnvironment: ThomasSelectorEnvironment, border: ThomasBorder?)
        -> some View
    {
        let strokeColor = border?.strokeColor?.toColor(selectorEnvironment)
        let strokeWidth = border?.strokeWidth ?? 0

        if let strokeColor = strokeColor, strokeWidth > 0 {
            Ellipse().strokeBorder(strokeColor, lineWidth: strokeWidth)
        } else {
            Ellipse()
        }
    }

    @ViewBuilder
    @MainActor
    fileprivate static func ellipse(
        info: ThomasShapeInfo.Ellipse,
        constraints: ViewConstraints,
        selectorEnvironment: ThomasSelectorEnvironment
    ) -> some View {
        let scaled = scaledConstraints(constraints, scale: info.scale)
        let color = info.color?.toColor(selectorEnvironment) ?? Color.clear
        if let border = info.border {
            ellipse(selectorEnvironment: selectorEnvironment, border: border)
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

/// A single shape, extracted into its own concrete `View` type for the same reason as
/// `IconsContent`: inlining the two-case `@ViewBuilder` switch (whose cases each return a
/// `constraints`-wrapped opaque result) into callers' bodies builds an opaque-type tree that the
/// optimizer can't substitute under `-O`. Shapes come in stacks — a toggle style or a score item
/// renders several plus an icon — so the caller multiplies whatever this returns. Referencing a
/// named struct keeps those bodies one node wide per shape while preserving full static typing
/// (and so view identity and animations), unlike erasing to `AnyView`.
@MainActor
private struct ShapeContent: View {
    fileprivate let info: ThomasShapeInfo
    fileprivate let constraints: ViewConstraints
    fileprivate let selectorEnvironment: ThomasSelectorEnvironment

    var body: some View {
        switch info {
        case .ellipse(let info):
            Shapes.ellipse(
                info: info,
                constraints: constraints,
                selectorEnvironment: selectorEnvironment
            )
        case .rectangle(let info):
            Shapes.rectangle(
                info: info,
                constraints: constraints,
                selectorEnvironment: selectorEnvironment
            )
        }
    }
}
