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

    var body: some View {
        ZStack {
            ForEach(0..<self.model.items.count, id: \.self) { index in
                childItem(item: self.model.items[index])
            }
        }
        .constraints(constraints)
        .background(model.backgroundColor)
        .border(model.border)
    }
    
    @ViewBuilder
    private func childItem(item: ContainerItem) -> some View {
        let alignment = Alignment(horizontal: item.position.horizontal.toAlignment(),
                                  vertical: item.position.vertical.toAlignment())
        
        let childConstraints = ViewConstraints.calculateChildConstraints(childSize: item.size,
                                                                         parentConstraints: constraints)

        
        let childFrameConstraints = ViewConstraints.calculateChildConstraints(childSize: item.size,
                                                                              parentConstraints: constraints,
                                                                              childMargins: item.margin)
        
        ZStack {
            ViewFactory.createView(model: item.view, constraints: childConstraints)
                .constraints(childFrameConstraints)
                .margin(item.margin)
        }.frame(maxWidth: alignment.horizontal == .center ? nil : .infinity,
                maxHeight: alignment.vertical == .center ? nil : .infinity,
                alignment: alignment)
    }
}
