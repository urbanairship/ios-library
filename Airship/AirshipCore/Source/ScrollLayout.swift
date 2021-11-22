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
    
    @State private var isScrollable: Bool = true

    var body: some View {
        let width = self.model.direction == .vertical ? self.constraints.width : nil
        let height = self.model.direction == .vertical ? nil : self.constraints.height
        
        let childConstraints = ViewConstraints(width: width, height: height)
        
        GeometryReader { parentMetrics in
            if (isScrollable) {
                ScrollView(self.model.direction == .vertical ? .vertical : .horizontal) {
                    ViewFactory.createView(model: self.model.view, constraints: childConstraints)
                        .background(GeometryReader { contentMetrics in
                            Color.clear.preference(key: ScrollablePreferenceKey.self,
                                                   value: scrollable(parent: parentMetrics, content: contentMetrics))
                        })
                        .onPreferenceChange(ScrollablePreferenceKey.self) {
                            self.isScrollable = $0
                        }
                }
            } else {
                ViewFactory.createView(model: self.model.view, constraints: childConstraints)
                    .background(GeometryReader { contentMetrics in
                        Color.clear.preference(key: ScrollablePreferenceKey.self,
                                               value: scrollable(parent: parentMetrics, content: contentMetrics))
                    })
                    .onPreferenceChange(ScrollablePreferenceKey.self) {
                        self.isScrollable = $0
                    }
            }
        }
        .constraints(self.constraints)
        .background(self.model.backgroundColor)
        .border(self.model.border)
    }
    
    private func scrollable(parent: GeometryProxy, content: GeometryProxy) -> Bool {
        var isScrollable = false
        if (self.model.direction == .vertical) {
            isScrollable =  content.size.height >= parent.size.height
        } else {
            isScrollable =  content.size.width >= parent.size.width
        }
        
        print(isScrollable)
        return isScrollable
    }
}

private struct ScrollablePreferenceKey: PreferenceKey {
    static var defaultValue: Bool = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }

    typealias Value = Bool
}
