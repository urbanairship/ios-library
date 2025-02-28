/* Copyright Airship and Contributors */

import Foundation
import SwiftUI


struct Icons {

    private static func makeSystemImageIcon(
        name: String,
        resizable: Bool,
        color: Color
    ) -> some View {
        Image(systemName: name)
            .resizable(resizable)
            .foregroundColor(color)
    }

    @ViewBuilder
    private static func makeView(
        icon: ThomasIconInfo.Icon,
        resizable: Bool,
        color: Color
    ) -> some View {
        switch icon {
        case .checkmark:
            makeSystemImageIcon(
                name: "checkmark",
                resizable: resizable,
                color: color
            )
        case .close:
            makeSystemImageIcon(
                name: "xmark",
                resizable: resizable,
                color: color
            )
        case .backArrow:
            makeSystemImageIcon(
                name: "arrow.backward",
                resizable: resizable,
                color: color
            )
        case .forwardArrow:
            makeSystemImageIcon(
                name: "arrow.forward",
                resizable: resizable,
                color: color
            )
        case .exclamationmarkCircleFill:
            makeSystemImageIcon(
                name: "exclamationmark.circle.fill",
                resizable: resizable,
                color: color
            )
        case .progressSpinner:
            ProgressView().tint(color)
        }
    }

    @ViewBuilder
    @MainActor
    static func icon(
        info: ThomasIconInfo,
        colorScheme: ColorScheme,
        resizable: Bool = true
    ) -> some View {
        makeView(
            icon: info.icon,
            resizable: resizable,
            color: info.color.toColor(colorScheme)
        )
        .aspectRatio(contentMode: .fit)
        .airshipApplyIf(info.scale != nil) { view in
            view.scaleEffect(info.scale ?? 1)
        }
    }
}

extension Image {
    @ViewBuilder
    func resizable(_ isResizable: Bool) -> some View  {
        if isResizable {
            self.resizable()
        } else {
            self
        }
    }
}
