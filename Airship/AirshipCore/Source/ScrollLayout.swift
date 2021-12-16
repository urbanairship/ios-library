/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Scroll view layout
@available(iOS 13.0.0, tvOS 13.0, *)
struct ScrollLayout : View {

    /// ScrollLayout model.
    let model: ScrollLayoutModel
    
    /// View constriants.
    let constraints: ViewConstraints
    
    @State private var contentSize: (ViewConstraints, CGSize)? = nil
    @State private var isScrollable = true

    @ViewBuilder
    func content(parentMetrics: GeometryProxy, constraints: ViewConstraints) -> some View {
        ViewFactory.createView(model: self.model.view, constraints: constraints)
            .background(
                GeometryReader { geometryProxy in
                    Color.clear.preference(key: ScrollViewContentSizePreferenceKey.self, value: geometryProxy.size)
                }
            )
            .onPreferenceChange(ScrollViewContentSizePreferenceKey.self) { newSize in
                contentSize = (constraints, newSize)
                let isScrollable = scrollable(parent: parentMetrics.size, content: newSize)
                if (isScrollable != self.isScrollable) {
                    self.isScrollable = isScrollable
                    print("something - isScrollable: \(self.isScrollable)")
                }
            }
            .onScrollStart {
                print ("on scroll start")
                guard let contentSize = contentSize, contentSize.0 == self.constraints else {
                    return
                }
                let isScrollable = scrollable(parent: parentMetrics.size, content: contentSize.1)
                if (isScrollable != self.isScrollable) {
                    self.isScrollable = isScrollable
                    print("start - isScrollable: \(self.isScrollable)")
                }
            }
    }
    var body: some View {
        GeometryReader { parentMetrics in
            let isVertical = self.model.direction == .vertical
            let width = isVertical ? self.constraints.width : nil
            let height = isVertical ? nil : self.constraints.height
            
            let childConstraints = ViewConstraints(width: width,
                                                   height: height,
                                                   safeAreaInsets: self.constraints.safeAreaInsets)
            
            let axis = isVertical ? Axis.Set.vertical : Axis.Set.horizontal

            if (self.isScrollable) {
                ScrollView(axis) {
                    content(parentMetrics: parentMetrics, constraints: childConstraints)
                }
                .clipped()
            } else {
                content(parentMetrics: parentMetrics, constraints: childConstraints)
            }
        }
        .constraints(self.constraints)
        .background(self.model.backgroundColor)
        .border(self.model.border)
    }
    
    private func scrollable(parent: CGSize, content: CGSize) -> Bool {
        var isScrollable = false
        if (self.model.direction == .vertical) {
            isScrollable = content.height >= parent.height
        } else {
            isScrollable = content.width >= parent.width
        }
        
        return isScrollable
    }
}


struct ScrollViewContentSizePreferenceKey: PreferenceKey {
  static var defaultValue: CGSize = .zero
  static func reduce(value: inout CGSize, nextValue: () -> CGSize) {}
}


@available(iOS 13.0.0, tvOS 13.0, *)
extension View {
    @ViewBuilder
    func onScrollStart(perform: @escaping () -> Void) -> some View {
        #if !os(tvOS)
        self.simultaneousGesture(
            DragGesture()
                .onChanged {_ in
                    perform()
                }
            )
        #else
        self
        #endif
    }
}

