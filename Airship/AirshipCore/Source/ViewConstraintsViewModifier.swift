/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct ViewConstraintsViewModifier: ViewModifier {
    let viewConstraints: ViewConstraints
    
    func body(content: Content) -> some View {
        content.frame(width: viewConstraints.width, height: viewConstraints.height)
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
extension View {
    @ViewBuilder
    func constraints(_ constraints: ViewConstraints) -> some View {
        self.modifier(ViewConstraintsViewModifier(viewConstraints: constraints))
    }
}

