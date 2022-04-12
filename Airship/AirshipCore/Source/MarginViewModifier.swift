/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct MarginViewModifier: ViewModifier {
    let margin: Margin
    
    @ViewBuilder
    func body(content: Content) -> some View {
        content
            .applyMargin(edge: .leading, margin: margin.start)
            .applyMargin(edge: .top, margin: margin.top)
            .applyMargin(edge: .trailing, margin: margin.end)
            .applyMargin(edge: .bottom, margin: margin.bottom)
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
extension View {
    
    @ViewBuilder
    internal func applyMargin(edge: Edge.Set, margin: CGFloat?) -> some View {
        if let margin = margin {
            self.padding(edge, margin)
        } else {
            self
        }
    }
    
    @ViewBuilder
    func margin(_ margin: Margin?) -> some View {
        if let margin = margin {
            self.modifier(MarginViewModifier(margin: margin))
        } else {
            self
        }
    }
}
