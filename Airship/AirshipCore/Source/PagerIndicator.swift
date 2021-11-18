/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct PagerIndicator : View {
    
    let model: PagerIndicatorModel
    let constraints: ViewConstraints
    
    @EnvironmentObject var pagerState: PagerState
    @Environment(\.colorScheme) var colorScheme
    
    @ViewBuilder
    private func createChild(binding: PagerIndicatorModel.Binding, height: CGFloat) -> some View {
        ZStack {
            if let shapes = binding.shapes {
                ForEach(0..<shapes.count, id: \.self) { index in
                    Shapes.shape(model: shapes[index], colorScheme: colorScheme)
                        .frame(height: height)
                }
            }
            
            if let iconModel = binding.icon {
                Icons.icon(model: iconModel, colorScheme: colorScheme)
                    .frame(height: height)
            }
        }
    }
    
    var body: some View {
        let height = constraints.height ?? 32.0
        HStack(spacing: self.model.spacing) {
            ForEach(0..<self.pagerState.pages, id: \.self) { index in
                if (self.pagerState.index == index) {
                    createChild(binding: self.model.bindings.selected, height: height)
                } else {
                    createChild(binding: self.model.bindings.unselected, height: height)
                }
            }
        }
        .animation(nil)
        .constraints(constraints)
        .background(self.model.backgroundColor)
        .border(self.model.border)
    }
}
