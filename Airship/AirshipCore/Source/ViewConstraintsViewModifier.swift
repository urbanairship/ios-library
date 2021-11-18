/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct ViewConstraintsViewModifier: ViewModifier {
    let viewConstraints: ViewConstraints
    let alignment: Alignment?
    func body(content: Content) -> some View {
        
        let width = viewConstraints.width
        let height = viewConstraints.height
        
        if let alignment = alignment {
            content.frame(idealWidth: width,
                          maxWidth: width,
                          idealHeight: height,
                          maxHeight: height,
                          alignment: alignment)
        } else {
            content.frame(idealWidth: width,
                          maxWidth: width,
                          idealHeight: height,
                          maxHeight: height)
        }
        
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

