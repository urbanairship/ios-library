/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct Shapes {
    
    @ViewBuilder
    private static func rectangle(border: Border?) -> some View {
        let strokeColor = border?.strokeColor?.toColor()
        let strokeWidth = border?.strokeWidth ?? 0
        let cornerRadius = border?.radius ?? 0
        
        if (cornerRadius > 0) {
            if let strokeColor = strokeColor, strokeWidth > 0 {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(strokeColor, lineWidth: strokeWidth)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            }
        } else {
            if let strokeColor = strokeColor, strokeWidth > 0 {
                Rectangle()
                    .strokeBorder(strokeColor, lineWidth: strokeWidth)
            } else {
                Rectangle()
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
    static func rectangle(color: HexColor?, border: Border?) -> some View {
        if let color = color?.toColor() {
            rectangle(border: border)
                .background(rectangleBackground(border: border, color: color))
        } else {
            rectangle(border: border)
        }
    }
    
    @ViewBuilder
    private static func circle(border: Border?) -> some View {
        let strokeColor = border?.strokeColor?.toColor()
        let strokeWidth = border?.strokeWidth ?? 0
        
        if let strokeColor = strokeColor, strokeWidth > 0 {
            Circle().strokeBorder(strokeColor, lineWidth: strokeWidth)
        } else {
            Circle()
        }
    }
    
    @ViewBuilder
    static func circle(color: HexColor?, border: Border?) -> some View {
        if let color = color?.toColor() {
            circle(border: border)
                .background(Circle().fill(color))
        } else {
            circle(border: border)
        }
    }
}



