/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct Shapes {
    
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
    static func rectangle(colorScheme: ColorScheme,
                          color: ThomasColor? = nil,
                          aspectRatio: Double? = nil,
                          scale: Double? = nil,
                          border: Border? = nil) -> some View {
        let resolvedColor = color?.toColor(colorScheme) ?? Color.clear
        
        if let border = border {
            rectangle(colorScheme: colorScheme, border: border)
                .background(rectangleBackground(border: border, color: resolvedColor))
                .applyIf(aspectRatio != nil) { view in
                    view.aspectRatio(aspectRatio ?? 1, contentMode: .fit)
                }
                .applyIf(scale != nil) { view in
                    view.scaleEffect(scale ?? 1)
                }
        } else {
            Rectangle()
                .fill(resolvedColor)
                .applyIf(aspectRatio != nil) { view in
                    view.aspectRatio(aspectRatio ?? 1, contentMode: .fit)
                }
                .applyIf(scale != nil) { view in
                    view.scaleEffect(scale ?? 1)
                }
        }
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
    static func ellipse(colorScheme: ColorScheme,
                        color: ThomasColor? = nil,
                        aspectRatio: Double? = nil,
                        scale: Double? = nil,
                        border: Border? = nil) -> some View {
        let color = color?.toColor(colorScheme) ?? Color.clear
        if let border = border {

            
            ellipse(colorScheme: colorScheme, border: border)
                .applyIf(aspectRatio != nil) { view in
                    view.aspectRatio(aspectRatio ?? 1, contentMode: .fit)
                }
                .applyIf(scale != nil) { view in
                    view.scaleEffect(scale ?? 1)
                }
                .background(Ellipse().fill(color))
        } else {
            Ellipse()
                .fill(color)
                .applyIf(aspectRatio != nil) { view in
                    view.aspectRatio(aspectRatio ?? 1, contentMode: .fit)
                }
                .applyIf(scale != nil) { view in
                    view.scaleEffect(scale ?? 1)
                }
        }
    }
    
    @ViewBuilder
    static func shape(model: ShapeModel, colorScheme: ColorScheme) -> some View {
        switch(model) {
        case .ellipse(let ellipseModel):
            ellipse(colorScheme: colorScheme,
                    color: ellipseModel.color,
                    aspectRatio: ellipseModel.aspectRatio,
                    scale: ellipseModel.scale,
                    border: ellipseModel.border)
        case .rectangle(let rectangleModel):
            rectangle(colorScheme: colorScheme,
                      color: rectangleModel.color,
                      aspectRatio: rectangleModel.aspectRatio,
                      scale: rectangleModel.scale,
                      border: rectangleModel.border)
        }
    }
}



