/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct Shapes {

    @ViewBuilder
    static func shape(model: ShapeModel, constraints: ViewConstraints, colorScheme: ColorScheme) -> some View {
        switch(model) {
        case .ellipse(let ellipseModel):
            ellipse(model: ellipseModel,
                    constraints: constraints,
                    colorScheme: colorScheme)
        case .rectangle(let rectangleModel):
            rectangle(model: rectangleModel,
                      constraints: constraints,
                      colorScheme: colorScheme)
        }
    }

    @ViewBuilder
    private static func rectangle(colorScheme: ColorScheme, border: Border?) -> some View {
        let strokeColor = border?.strokeColor?.toColor(colorScheme) ?? Color.clear
        let strokeWidth = border?.strokeWidth ?? 0
        let cornerRadius = border?.radius ?? 0
        
        if (cornerRadius > 0) {
            if let strokeColor = strokeColor, strokeWidth > 0 {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(strokeColor, lineWidth: strokeWidth)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.clear)
            }
        } else {
            if let strokeColor = strokeColor, strokeWidth > 0 {
                Rectangle()
                    .strokeBorder(strokeColor, lineWidth: strokeWidth)
            } else {
                Rectangle().fill(Color.clear)
            }
        }
    }
    
    @ViewBuilder
    private static func rectangleBackground(border: Border?, color: Color) -> some View {
        let cornerRadius = border?.radius ?? 0
        if (cornerRadius > 0) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(color)
        } else {
            Rectangle()
                .fill(color)
        }
    }

    @ViewBuilder
    private static func rectangle(model: RectangleShapeModel,
                                  constraints: ViewConstraints,
                                  colorScheme: ColorScheme) -> some View {
        let resolvedColor = model.color?.toColor(colorScheme) ?? Color.clear
        if let border = model.border {
            rectangle(colorScheme: colorScheme, border: border)
                .background(rectangleBackground(border: border, color: resolvedColor))
                .aspectRatio(model.aspectRatio ?? 1, contentMode: .fit)
                .applyIf(model.scale != nil) { view in
                    view.constraints(scaledConstraints(constraints, scale: model.scale))
                }
                .constraints(constraints)
        } else {
            Rectangle()
                .fill(resolvedColor)
                .aspectRatio(model.aspectRatio ?? 1, contentMode: .fit)
                .applyIf(model.scale != nil) { view in
                    view.constraints(scaledConstraints(constraints, scale: model.scale))
                }
                .constraints(constraints)
        }
    }

    private static func scaledConstraints(_ constraints: ViewConstraints, scale: Double?) -> ViewConstraints {
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
    private static func ellipse(colorScheme: ColorScheme, border: Border?) -> some View {
        let strokeColor = border?.strokeColor?.toColor(colorScheme)
        let strokeWidth = border?.strokeWidth ?? 0

        if let strokeColor = strokeColor, strokeWidth > 0 {
            Ellipse().strokeBorder(strokeColor, lineWidth: strokeWidth)
        } else {
            Ellipse()
        }
    }
    
    @ViewBuilder
    private static func ellipse(model: EllipseShapeModel,
                                constraints: ViewConstraints,
                                colorScheme: ColorScheme) -> some View {
        let color = model.color?.toColor(colorScheme) ?? Color.clear
        let scaled = scaledConstraints(constraints, scale: model.scale)
        if let border = model.border {
            ellipse(colorScheme: colorScheme, border: border)
                .aspectRatio(model.aspectRatio ?? 1, contentMode: .fit)
                .background(Ellipse().fill(color))
                .applyIf(model.scale != nil) { view in
                    view.constraints(scaled)
                }
                .constraints(constraints)
        } else {
            Ellipse()
                .fill(color)
                .aspectRatio(model.aspectRatio ?? 1, contentMode: .fit)
                .applyIf(model.scale != nil) { view in
                    view.constraints(scaled)
                }
                .constraints(constraints)
        }
    }
}
