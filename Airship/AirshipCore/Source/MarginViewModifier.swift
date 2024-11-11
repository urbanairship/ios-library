/* Copyright Airship and Contributors */

import Foundation
import SwiftUI


struct MarginViewModifier: ViewModifier {
    let margin: ThomasMargin

    @ViewBuilder
    func body(content: Content) -> some View {
        content
            .applyMargin(edge: .leading, margin: margin.start)
            .applyMargin(edge: .top, margin: margin.top)
            .applyMargin(edge: .trailing, margin: margin.end)
            .applyMargin(edge: .bottom, margin: margin.bottom)
    }
}

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
    func margin(_ margin: ThomasMargin?) -> some View {
        if let margin = margin {
            self.modifier(MarginViewModifier(margin: margin))
        } else {
            self
        }
    }
}
