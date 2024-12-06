/* Copyright Airship and Contributors */

import Foundation
import SwiftUI


struct Icons {
    private static func createImage(icon: ThomasIconInfo.Icon) -> Image {
        switch icon {
        case .checkmark:
            return Image(systemName: "checkmark")
        case .close:
            return Image(systemName: "xmark")
        case .backArrow:
            return Image(systemName: "arrow.backward")
        case .forwardArrow:
            return Image(systemName: "arrow.forward")
        case .exclamationmarkCircleFill:
            return Image(systemName: "exclamationmark.circle.fill")
        }
    }

    @ViewBuilder
    @MainActor
    static func icon(
        info: ThomasIconInfo,
        colorScheme: ColorScheme,
        resizable: Bool = true
    ) -> some View {
        createImage(icon: info.icon)
            .airshipApplyIf(resizable) { view in
                view.resizable()
            }
            .aspectRatio(contentMode: .fit)
            .foregroundColor(info.color.toColor(colorScheme))
            .airshipApplyIf(info.scale != nil) { view in
                view.scaleEffect(info.scale ?? 1)
            }
    }
}
