/* Copyright Airship and Contributors */

import Foundation
import SwiftUI


struct Icons {

    @MainActor
    private static func makeSystemImageIcon(
        name: String,
        resizable: Bool,
        color: Color
    ) -> some View {
        Image(systemName: name)
            .airshipApplyIf(resizable) { view in view.resizable() }
            .foregroundColor(color)
    }

    @MainActor
    @ViewBuilder
    private static func makeView(
        icon: ThomasIconInfo.Icon,
        resizable: Bool,
        color: Color
    ) -> some View {
        switch icon {
        case .asterisk:
            makeSystemImageIcon(
                name: "asterisk",
                resizable: resizable,
                color: color
            )
        case .asteriskCicleFill:
            makeSystemImageIcon(
                name: "asterisk.circle.fill",
                resizable: resizable,
                color: color
            )
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
        case .chevronForward:
            makeSystemImageIcon(
                name: "chevron.forward",
                resizable: resizable,
                color: color
            )
        case .chevronBackward:
            makeSystemImageIcon(
                name: "chevron.backward",
                resizable: resizable,
                color: color
            )
        case .play:
            makeSystemImageIcon(
                name: "play.fill",
                resizable: resizable,
                color: color
            )
        case .pause:
            makeSystemImageIcon(
                name: "pause",
                resizable: resizable,
                color: color
            )
        case .exclamationmarkCircleFill:
            makeSystemImageIcon(
                name: "exclamationmark.circle.fill",
                resizable: resizable,
                color: color
            )
        case .star:
            makeSystemImageIcon(
                name: "star",
                resizable: resizable,
                color: color
            )
        case .starFill:
            makeSystemImageIcon(
                name: "star.fill",
                resizable: resizable,
                color: color
            )
        case .heart:
            makeSystemImageIcon(
                name: "heart",
                resizable: resizable,
                color: color
            )
        case .heartFill:
            makeSystemImageIcon(
                name: "heart.fill",
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
