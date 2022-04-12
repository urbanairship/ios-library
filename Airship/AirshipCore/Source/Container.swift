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

    @State private var contentSize: (ViewConstraints, CGSize)? = nil

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
            GeometryReader(content: { contentMetrics -> Color in
                DispatchQueue.main.async {
                    self.contentSize  = (self.constraints, contentMetrics.size)
                }
                return Color.clear
            })
        )
    }
    
    @ViewBuilder
    private func childItem(item: ContainerItem) -> some View {
        let placementWidth =  placementWidth(item.position.horizontal)
        let placementHeight = placementHeight(item.position.vertical)

        let alignment = Alignment(horizontal: item.position.horizontal.toAlignment(),
                                  vertical: item.position.vertical.toAlignment())

        let borderPadding = self.model.border?.strokeWidth ?? 0
        let childConstraints = self.constraints.calculateChild(item.size,
                                                               margin: item.margin,
                                                               additionalPadding: borderPadding,
                                                               ignoreSafeArea: item.ignoreSafeArea)
  
        ZStack {
            ViewFactory.createView(model: item.view, constraints: childConstraints)
                .margin(item.margin)
                .padding(borderPadding)
        }
        .applyIf(item.ignoreSafeArea != true) {
            $0.padding(self.constraints.safeAreaInsets)
        }
        .frame(idealWidth: placementWidth,
               maxWidth: placementWidth,
               idealHeight: placementHeight,
               maxHeight: placementHeight,
               alignment: alignment)
    }
    
    private func placementWidth(_ position: HorizontalPosition) -> CGFloat? {
        guard (constraints.width == nil) else { return constraints.width }
        guard position != .center else { return nil }

        if let contentSize = contentSize, contentSize.0 == self.constraints {
            return contentSize.1.width > 0 ? contentSize.1.width : nil
        }
        
        return nil
    }
    
    private func placementHeight(_ position: VerticalPosition) -> CGFloat? {
        guard (constraints.height == nil) else { return constraints.height }
        guard position != .center else { return nil }

        if let contentSize = contentSize, contentSize.0 == self.constraints {
            return contentSize.1.height > 0 ? contentSize.1.height : nil
        }
        
        return nil
    }
}
