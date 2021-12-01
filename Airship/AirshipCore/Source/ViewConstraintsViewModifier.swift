/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct ViewConstraintsViewModifier: ViewModifier {
    let viewConstraints: ViewConstraints
    let alignment: Alignment?
    func body(content: Content) -> some View {
        content.frame(minWidth: viewConstraints.minWidth,
                      idealWidth: viewConstraints.width,
                      maxWidth: viewConstraints.maxWidth ?? viewConstraints.width,
                      minHeight: viewConstraints.minHeight,
                      idealHeight: viewConstraints.height,
                      maxHeight: viewConstraints.maxHeight ?? viewConstraints.height,
                      alignment: alignment ?? .center)
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
extension View {
    @ViewBuilder
    func constraints(_ constraints: ViewConstraints, alignment: Alignment? = nil) -> some View {
        self.modifier(ViewConstraintsViewModifier(viewConstraints: constraints,
                                                  alignment: alignment))
    }
}

