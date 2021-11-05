/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct PagerIndicator : View {
    
    @EnvironmentObject var pagerState: PagerState

    let model: PagerIndicatorModel
    let constraints: ViewConstraints
    
    @ViewBuilder
    func createShape(shapeModel: ShapeModel) -> some View {
        switch (shapeModel) {
        case .circle(let model):
            Shapes.circle(color: model.color, border: model.border)
                .frame(width: model.radius * 2, height: model.radius * 2)
        case .rectangle(let model):
            Shapes.rectangle(color: model.color, border: model.border)
                .frame(width: model.width, height: model.height)
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
