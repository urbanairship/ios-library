/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct ViewConstraintsViewModifier: ViewModifier {
    let viewConstraints: ViewConstraints
    
    let alignment: Alignment?
    func body(content: Content) -> some View {
        if let alignment = alignment {
            content.frame(idealWidth: viewConstraints.frameWidth,
                          maxWidth: viewConstraints.frameWidth,
                          idealHeight: viewConstraints.frameHeight,
                          maxHeight: viewConstraints.frameHeight,
                          alignment: alignment)
        } else {
            content.frame(idealWidth: viewConstraints.frameWidth,
                          maxWidth: viewConstraints.frameWidth,
                          idealHeight: viewConstraints.frameHeight,
                          maxHeight: viewConstraints.frameHeight)
        }
        
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
extension View {
    @ViewBuilder
    func constraints(_ constraints: ViewConstraints) -> some View {
        self.modifier(ViewConstraintsViewModifier(viewConstraints: constraints, alignment: nil))
    }
    
    @ViewBuilder
    func constraints(_ constraints: ViewConstraints, alignment: Alignment?) -> some View {
        self.modifier(ViewConstraintsViewModifier(viewConstraints: constraints, alignment: alignment))
    }
}

