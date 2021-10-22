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
        .frame(minWidth: constraints.minWidth,
               idealWidth: constraints.width,
               maxWidth: constraints.width,
               minHeight: constraints.minHeight,
               idealHeight: constraints.height,
               maxHeight: constraints.height)
        .background(model.background)
        .border(model.border)
    }
    
    @ViewBuilder
    private func childItem(item: ContainerItem) -> some View {
        let alignment = Alignment(horizontal: item.position.horizontal.toAlignment(),
                                  vertical: item.position.vertical.toAlignment())
        
        let childConstraints = ViewConstraints.calculateChildConstraints(childSize: item.size,
                                                                         childMargins: item.margin,
                                                                         parentConstraints: constraints)
        ZStack {
            ViewFactory.createView(model: item.view,
                                   constraints: childConstraints)
                .margin(item.margin)
        }
        .frame(idealWidth: constraints.width,
               maxWidth: constraints.width,
               idealHeight: constraints.height,
               maxHeight: constraints.height,
               alignment: alignment)
    }
}
