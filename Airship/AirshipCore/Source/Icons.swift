/* Copyright Airship and Contributors */

import Foundation
import SwiftUI


struct Icons {

    @MainActor
    static func makeSystemImageIcon(
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
    fileprivate static func makeView(
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
        case .mute:
            makeSystemImageIcon(
                name: "speaker.slash.fill",
                resizable: resizable,
                color: color
            )
        case .unmute:
            makeSystemImageIcon(
                name: "speaker.wave.2.fill",
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
            ProgressSpinnerIconView(
                resizable: resizable,
                color: color
            )
        }
    }

    @MainActor
    static func icon(
        info: ThomasIconInfo,
        colorScheme: ColorScheme,
        resizable: Bool = true
    ) -> some View {
        IconsContent(info: info, colorScheme: colorScheme, resizable: resizable)
    }
}

/// The content of a single icon, extracted into its own concrete `View` type.
///
/// Inlining `Icons.makeView(...)` (a 17-case @ViewBuilder switch where each case
/// returns the opaque result of `makeSystemImageIcon`) directly in callers' bodies
/// builds an opaque-type tree large enough to crash the Swift optimizer under
/// -O + library evolution (non-terminating substOpaqueTypesWithUnderlyingTypes in
/// SILGen). Referencing a named struct keeps callers' type trees small while
/// preserving full static typing (and thus view identity / animations), unlike
/// erasing to `AnyView`.
@MainActor
private struct IconsContent: View {
    let info: ThomasIconInfo
    let colorScheme: ColorScheme
    let resizable: Bool

    var body: some View {
        Icons.makeView(
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

@MainActor
private struct ProgressSpinnerIconView: View {
    let resizable: Bool
    let color: Color
    // Only used for < 18
    @State private var isSpinning: Bool = false
    
    var body: some View {
        if #available(iOS 18.0, visionOS 2.0, *) {
            Icons.makeSystemImageIcon(
                name: "progress.indicator",
                resizable: resizable,
                color: color
            )
            .symbolEffect(.variableColor.iterative, options: .repeat(.continuous))
        } else {
            Icons.makeSystemImageIcon(
                name: "rays",
                resizable: resizable,
                color: color
            )
            .rotationEffect(.degrees(isSpinning ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    isSpinning = true
                }
            }
        }
    }

}
