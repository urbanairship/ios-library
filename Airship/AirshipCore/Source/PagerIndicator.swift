/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
@_spi(AirshipInternal) import AirshipBasement

struct PagerIndicator: View {

    let info: ThomasViewInfo.PagerIndicator
    let constraints: ViewConstraints

    @EnvironmentObject var pagerState: PagerState
    @Environment(\.colorScheme) var colorScheme

    func announcePage(info: ThomasViewInfo.PagerIndicator) -> Bool {
        return info.properties.automatedAccessibilityActions?.contains{ $0.type == .announce} ?? false
    }

    var body: some View {
        let size: Double = if let height = constraints.height {
            height - (self.info.commonProperties.border?.strokeWidth ?? 0)
        } else {
            32.0
        }
        
        let childConstraints = ViewConstraints(
            width: size,
            height: size
        )

        HStack(spacing: self.info.properties.spacing) {
            ForEach(0..<self.pagerState.pageStates.count, id: \.self) { index in
                if self.pagerState.pageIndex == index {
                    PagerIndicatorChild(
                        binding: self.info.properties.bindings.selected,
                        constraints: childConstraints
                    )
                } else {
                    PagerIndicatorChild(
                        binding: self.info.properties.bindings.unselected,
                        constraints: childConstraints
                    )
                }
            }
        }
        .padding(.horizontal, self.info.properties.spacing)
        .animation(.interactiveSpring(duration: Pager.animationSpeed), value: self.info)
        .constraints(constraints)
        .thomasCommon(self.info)
        .airshipApplyIf(announcePage(info: self.info), transform: { view in
            view.accessibilityLabel(String(format: "ua_pager_progress".airshipLocalizedString(
                fallback: "Page %@ of %@"
            ), (self.pagerState.pageIndex + 1).airshipLocalizedForVoiceOver(), self.pagerState.pageStates.count.airshipLocalizedForVoiceOver()))
        })
        .accessibilityHidden(true)
    }
}

/// A single pager indicator child, extracted into its own concrete `View` type.
///
/// Inlining this `ZStack`/`ForEach` directly in `PagerIndicator.body` (on top of the
/// `constraints`/`thomasCommon`/`airshipApplyIf` modifier chain) builds an opaque-type
/// tree large enough to crash the Xcode 27 / Swift 6.4 optimizer under -O + library
/// evolution (non-terminating substOpaqueTypesWithUnderlyingTypes in SILGen).
/// Referencing a named struct keeps `body`'s type tree small while preserving full
/// static typing (and thus view identity / animations), unlike erasing to `AnyView`.
private struct PagerIndicatorChild: View {

    let binding: ThomasViewInfo.PagerIndicator.Properties.Binding
    let constraints: ViewConstraints

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if let shapes = binding.shapes {
                ForEach(0..<shapes.count, id: \.self) { index in
                    Shapes.shape(
                        info: shapes[index],
                        constraints: constraints,
                        colorScheme: colorScheme
                    )
                }
            }

            if let iconModel = binding.icon {
                Icons.icon(
                    info: iconModel,
                    colorScheme: colorScheme
                )
            }
        }
    }
}
