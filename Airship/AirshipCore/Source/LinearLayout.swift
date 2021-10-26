/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Linear Layout - either a VStack or HStack depending on the direction.
@available(iOS 13.0.0, tvOS 13.0, *)
struct LinearLayout : View {
    
    /// LinearLayout model.
    let model: LinearLayoutModel
    
    /// View constriants.
    let constraints: ViewConstraints

    @ViewBuilder
    func createStack() -> some View {
        if (self.model.direction == .vertical) {
            VStack(alignment: .center, spacing: 0) {
                ForEach(0..<self.model.items.count, id: \.self) { index in
                    childItem(item: self.model.items[index])
                }
            }
        } else {
            HStack() {
                ForEach(0..<self.model.items.count, id: \.self) { index in
                    childItem(item: self.model.items[index])
                }
            }
        }
    }
                        
    var body: some View {
        createStack()
            .frame(idealWidth: constraints.width,
                   maxWidth: constraints.width,
                   idealHeight: constraints.height,
                   maxHeight: constraints.height,
                   alignment: .topLeading)
            .background(self.model.backgroundColor)
            .border(self.model.border)
    }
    
    @ViewBuilder
    private func childItem(item: LinearLayoutItem) -> some View {
        let childConstraints = ViewConstraints.calculateChildConstraints(childSize: item.size,
                                                                         childMargins: item.margin,
                                                                         parentConstraints: constraints)
        ViewFactory.createView(model: item.view, constraints: childConstraints)
            .margin(item.margin)
    }
}
