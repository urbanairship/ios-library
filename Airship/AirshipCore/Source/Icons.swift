/* Copyright Airship and Contributors */

import Foundation
import SwiftUI


struct Icons {

    private static func createImage(icon: Icon) -> Image {
        switch icon {
        case .checkmark:
            return Image(systemName: "checkmark")
        case .close:
            return Image(systemName: "xmark")
        case .backArrow:
            return Image(systemName: "arrow.backward")
        case .forwardArrow:
            return Image(systemName: "arrow.forward")
        }
    }

    @ViewBuilder
    static func icon(
        model: IconModel,
        colorScheme: ColorScheme
    ) -> some View {
        createImage(icon: model.icon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundColor(model.color.toColor(colorScheme))
            .applyIf(model.scale != nil) { view in
                view.scaleEffect(model.scale ?? 1)
            }
    }
}
