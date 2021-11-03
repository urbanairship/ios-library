/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct PagerIndicator : View {
    
    @EnvironmentObject var pagerState: PagerState

    let model: PagerIndicatorModel
    let constraints: ViewConstraints
    
    @ViewBuilder
    func createShape(shapeModel: BaseShapeModel) -> some View {
        switch (shapeModel) {
        case let shape as CircleShapeModel:
            Shapes.circle(color: shape.color, border: shape.border)
                .frame(width: shape.radius * 2, height: shape.radius * 2)
        case let shape as RectangleShapeModel:
            Shapes.rectangle(color: shape.color, border: shape.border)
                .frame(width: shape.width, height: shape.height)
        default:
            Shapes.rectangle(color: shapeModel.color, border: shapeModel.border)
        }
    }
    
    var body: some View {
        HStack(spacing: self.model.spacing) {
            ForEach((0..<self.pagerState.pages), id: \.self) { index in
                if (self.pagerState.index == index) {
                    createShape(shapeModel: self.model.bindings.selected)
                } else {
                    createShape(shapeModel: self.model.bindings.deselected)
                }
            }
        }
        .animation(nil)
    }
}
