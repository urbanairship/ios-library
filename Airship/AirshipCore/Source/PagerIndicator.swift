/* Copyright Airship and Contributors */


import SwiftUI

struct PagerIndicator: View {

    let info: ThomasViewInfo.PagerIndicator
    let constraints: ViewConstraints

    @EnvironmentObject var pagerState: PagerState
    @Environment(\.colorScheme) var colorScheme

    @ViewBuilder
    private func createChild(
        binding: ThomasViewInfo.PagerIndicator.Properties.Binding,
        constraints: ViewConstraints
    ) -> some View {
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
                    createChild(
                        binding: self.info.properties.bindings.selected,
                        constraints: childConstraints
                    )
                } else {
                    createChild(
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
            view.accessibilityLabel(String(format: "ua_pager_progress".airshipLocalizedString(), (self.pagerState.pageIndex + 1).airshipLocalizedForVoiceOver(), self.pagerState.pageStates.count.airshipLocalizedForVoiceOver()))
        })
    }
}
