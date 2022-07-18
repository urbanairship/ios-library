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
                childItem(index, item: self.model.items[index])
            }
        }
        .constraints(constraints)
        .clipped()
        .background(self.model.backgroundColor)
        .border(self.model.border)
        .background(
            GeometryReader(content: { contentMetrics -> Color in
                let size = contentMetrics.size
                DispatchQueue.main.async {
                    self.contentSize  = (self.constraints, size)
                }
                return Color.clear
            })
        )
        .common(self.model)
    }
    
    @ViewBuilder
    private func childItem(_ index: Int, item: ContainerItem) -> some View {
        let placementWidth =  placementWidth(item.position.horizontal)
        let placementHeight = placementHeight(item.position.vertical)
        let consumeSafeAreaInsets = item.ignoreSafeArea != true

        let alignment = Alignment(horizontal: item.position.horizontal.toAlignment(),
                                  vertical: item.position.vertical.toAlignment())

        let borderPadding = self.model.border?.strokeWidth ?? 0
        let childConstraints = self.constraints.childConstraints(item.size,
                                                                 margin: item.margin,
                                                                 padding: borderPadding,
                                                                 safeAreaInsetsMode: consumeSafeAreaInsets ? .consumeMargin : .ignore)
  
        ZStack {
            ViewFactory.createView(model: item.view, constraints: childConstraints)
                .margin(item.margin)
        }
        .applyIf(consumeSafeAreaInsets) {
            $0.padding(self.constraints.safeAreaInsets)
        }
        .padding(borderPadding)
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
