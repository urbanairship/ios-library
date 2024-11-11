/* Copyright Airship and Contributors */

import Foundation
import SwiftUI


struct ViewConstraintsViewModifier: ViewModifier {
    let viewConstraints: ViewConstraints
    let alignment: Alignment?
    let fixedSize: Bool
    func body(content: Content) -> some View {
        content.frame(
            idealWidth: viewConstraints.width,
            maxWidth: viewConstraints.width,
            idealHeight: viewConstraints.height,
            maxHeight: viewConstraints.height,
            alignment: alignment ?? .center
        )
        .airshipApplyIf(fixedSize) { view in
            view.fixedSize(
                horizontal: viewConstraints.isHorizontalFixedSize
                    && viewConstraints.width != nil,
                vertical: viewConstraints.isVerticalFixedSize
                    && viewConstraints.height != nil
            )
        }
    }
}


extension View {
    @ViewBuilder
    func constraints(
        _ constraints: ViewConstraints,
        alignment: Alignment? = nil,
        fixedSize: Bool = false
    ) -> some View {
        self.modifier(
            ViewConstraintsViewModifier(
                viewConstraints: constraints,
                alignment: alignment,
                fixedSize: fixedSize
            )
        )
    }
}
