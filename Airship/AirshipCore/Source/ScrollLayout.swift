/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import MapKit

/// Scroll view layout
@available(iOS 13.0.0, tvOS 13.0, *)
struct ScrollLayout : View {

    /// ScrollLayout model.
    let model: ScrollLayoutModel
    
    /// View constriants.
    let constraints: ViewConstraints
    
    @State private var contentSize: (ViewConstraints, CGSize)? = nil
    @State private var isScrollable = true
    
    init(model: ScrollLayoutModel, constraints: ViewConstraints) {
        self.model = model
        self.constraints = constraints
    }

    @ViewBuilder
    func content(parentMetrics: GeometryProxy, constraints: ViewConstraints) -> some View {
        let parentSize = parentMetrics.size
        ZStack {
            ViewFactory.createView(model: self.model.view, constraints: constraints)
                .background(
                    GeometryReader(content: { contentMetrics -> Color in
                        let size = contentMetrics.size
                        DispatchQueue.main.async {
                            self.contentSize = (self.constraints, size)
                            updateScrollable(parentSize)
                        }
                        return Color.clear
                    })
                )
                .fixedSize(horizontal: self.model.direction == .horizontal, vertical: self.model.direction == .vertical)
        }.frame(alignment: .topLeading)
    }

    var body: some View {
        GeometryReader { parentMetrics in
            let isVertical = self.model.direction == .vertical
            let childConstraints = childConstraints()
            let axis = isVertical ? Axis.Set.vertical : Axis.Set.horizontal
            
            ScrollView(self.isScrollable ? axis : []) {
                content(parentMetrics: parentMetrics, constraints: childConstraints)
                if #available(iOS 14.0, tvOS 14.0, *) {} else {
                    Spacer()
                }
            }
            .clipped()
        }
        .constraints(self.constraints)
        .background(self.model.backgroundColor)
        .border(self.model.border)
        .common(self.model)
    }

    private func childConstraints() -> ViewConstraints {
        var childConstraints = constraints
        if (self.model.direction == .vertical) {
            childConstraints.height = nil
            childConstraints.isVerticalFixedSize = false
        } else {
            childConstraints.width = nil
            childConstraints.isHorizontalFixedSize = false
        }

        return childConstraints
    }
    
    private func updateScrollable(_ parentSize: CGSize) {
        guard let contentSize = contentSize, contentSize.0 == self.constraints else {
            return
        }
        let isScrollable = scrollable(parent: parentSize, content: contentSize.1)
        if (isScrollable != self.isScrollable) {
            self.isScrollable = isScrollable
        }
    }
    
    private func scrollable(parent: CGSize, content: CGSize) -> Bool {
        var isScrollable = false
        if (self.model.direction == .vertical) {
            isScrollable = content.height > parent.height
        } else {
            isScrollable = content.width > parent.width
        }
        return isScrollable
    }
}
