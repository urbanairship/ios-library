/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Container view.
@available(iOS 13.0.0, tvOS 13.0, *)
struct Container : View {

    /// Container model.
    let model: ContainerModel
    
    /// View constriants.
    let constraints: ViewConstraints
    @State private var size: CGSize?

    var body: some View {
        ZStack {
            ForEach(0..<self.model.items.count, id: \.self) { index in
                childItem(item: self.model.items[index])
            }
        }
        .constraints(constraints)
        .background(model.backgroundColor)
        .border(model.border)
        .background(
            GeometryReader { contentGeometry in
                Color.clear.onAppear {
                    self.size = contentGeometry.size
                }
            }
        )
    }
    
    @ViewBuilder
    private func childItem(item: ContainerItem) -> some View {
        // In order to place the children properly we need to know the content size
        // fallback to the measured width/height when not set by the constraints
        let contentConstraint = ViewConstraints(width: constraints.width ?? size?.width,
                                                height: constraints.height ?? size?.height)
        
        let alignment = Alignment(horizontal: item.position.horizontal.toAlignment(),
                                  vertical: item.position.vertical.toAlignment())
        
        let childConstraints = ViewConstraints.calculateChildConstraints(childSize: item.size,
                                                                         parentConstraints: contentConstraint)

        
        let childFrameConstraints = ViewConstraints.calculateChildConstraints(childSize: item.size,
                                                                              parentConstraints: contentConstraint,
                                                                              childMargins: item.margin)
        
        ZStack {
            ViewFactory.createView(model: item.view, constraints: childConstraints)
                .constraints(childFrameConstraints)
                .margin(item.margin)
        }
        .constraints(contentConstraint, alignment: alignment)
    }
}
