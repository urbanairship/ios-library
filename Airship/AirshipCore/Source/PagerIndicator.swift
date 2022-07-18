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
    private func createChild(binding: PagerIndicatorModel.Binding, constraints: ViewConstraints) -> some View {
        ZStack {
            if let shapes = binding.shapes {
                ForEach(0..<shapes.count, id: \.self) { index in
                    Shapes.shape(model: shapes[index],
                                 constraints: constraints,
                                 colorScheme: colorScheme)
                }
            }
            
            if let iconModel = binding.icon {
                Icons.icon(model: iconModel,
                           colorScheme: colorScheme)
            }
        }
    }
    
    var body: some View {
        let childConstraints = ViewConstraints(height: constraints.height ?? 32.0)

        HStack(spacing: self.model.spacing) {
            ForEach(0..<self.pagerState.pages.count, id: \.self) { index in
                if (self.pagerState.pageIndex == index) {
                    createChild(binding: self.model.bindings.selected,
                                constraints: childConstraints)
                } else {
                    createChild(binding: self.model.bindings.unselected,
                                constraints: childConstraints)
                }
            }
        }
        .animation(nil)
        .constraints(constraints)
        .background(self.model.backgroundColor)
        .border(self.model.border)
        .common(self.model)
    }
}
