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

    @State private var contentWidth: CGFloat? = nil
    @State private var contentHeight: CGFloat? = nil

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
            contentWidth = newSize.width == 0 ? nil : newSize.width
            contentHeight = newSize.height == 0 ? nil : newSize.height
        }
    }
    
    @ViewBuilder
    private func childItem(item: ContainerItem) -> some View {
        let alignment = Alignment(horizontal: item.position.horizontal.toAlignment(),
                                  vertical: item.position.vertical.toAlignment())
        
        let childConstraints = self.constraints.calculateChild(item.size,
                                                               ignoreSafeArea: item.ignoreSafeArea)
        
        let childFrameConstraints = self.constraints.calculateChild(item.size,
                                                                    margin: item.margin,
                                                                    ignoreSafeArea: item.ignoreSafeArea)
        
        ZStack {
            ViewFactory.createView(model: item.view, constraints: childConstraints)
                .constraints(childFrameConstraints)
                .margin(item.margin)
        }
        .applyIf(item.ignoreSafeArea != true) {
            $0.padding(self.constraints.safeAreaInsets)
        }
        .frame(width: self.constraints.width ?? contentWidth,
                height: self.constraints.height ?? contentHeight,
                alignment: alignment)
            
    }
}

struct ContainerSizePreferenceKey: PreferenceKey {
  static var defaultValue: CGSize = .zero
  static func reduce(value: inout CGSize, nextValue: () -> CGSize) {}
}
