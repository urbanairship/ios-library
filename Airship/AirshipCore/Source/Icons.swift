/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct Icons {
    
    private static func createImage(icon: Icon) -> Image {
        switch(icon) {
        case .checkmark:
            return Image(systemName: "checkmark")
        case .close:
            return Image(systemName: "xmark")
        case .leftArrow:
            return Image(systemName: "chevron.backward")
        case .rightArrow:
            return Image(systemName: "chevron.forward")
        }
    }
    
    @ViewBuilder
    static func icon(model: IconModel,
                     colorScheme: ColorScheme) -> some View {
        createImage(icon: model.icon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundColor(model.color.toColor(colorScheme))
            .applyIf(model.scale != nil) { view in
                view.scaleEffect(model.scale ?? 1)
            }
    }
}



