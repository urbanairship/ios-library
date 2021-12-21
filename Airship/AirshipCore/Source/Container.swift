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
            GeometryReader { geometryProxy in
                Color.clear.preference(key: ContainerSizePreferenceKey.self, value: geometryProxy.size)
            }
        )
        .onPreferenceChange(ContainerSizePreferenceKey.self) { newSize in
            contentSize = (constraints, newSize)
        }
    }
    
    @ViewBuilder
    private func childItem(item: ContainerItem) -> some View {
        let alignment = Alignment(horizontal: item.position.horizontal.toAlignment(),
                                  vertical: item.position.vertical.toAlignment())
        
        let childConstraints = self.constraints.calculateChild(item.size,
                                                               ignoreSafeArea: item.ignoreSafeArea)
  
        ZStack {
            ViewFactory.createView(model: item.view, constraints: childConstraints)
                .margin(item.margin)
        }
        .applyIf(item.ignoreSafeArea != true) {
            $0.padding(self.constraints.safeAreaInsets)
        }
        .frame(idealWidth: placementWidth(),
               maxWidth: self.constraints.width,
               idealHeight: placementHeight(),
               maxHeight: self.constraints.height,
               alignment: alignment)
            
    }
    
    private func placementWidth() -> CGFloat? {
        if let contentSize = contentSize, contentSize.0 == self.constraints {
            return contentSize.1.width > 0 ? contentSize.1.width : nil
        }
        
        return nil
    }
    
    private func placementHeight() -> CGFloat? {
        if let contentSize = contentSize, contentSize.0 == self.constraints {
            return contentSize.1.height > 0 ? contentSize.1.height : nil
        }
        
        return nil
    }
}

struct ContainerSizePreferenceKey: PreferenceKey {
  static var defaultValue: CGSize = .zero
  static func reduce(value: inout CGSize, nextValue: () -> CGSize) {}
}
