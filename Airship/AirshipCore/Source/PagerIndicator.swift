/* Copyright Airship and Contributors */

import Foundation
import SwiftUI


struct PagerIndicator: View {

    let model: PagerIndicatorModel
    let constraints: ViewConstraints

    @EnvironmentObject var pagerState: PagerState
    @Environment(\.colorScheme) var colorScheme

    @ViewBuilder
    private func createChild(
        binding: PagerIndicatorModel.Binding,
        constraints: ViewConstraints
    ) -> some View {
        ZStack {
            if let shapes = binding.shapes {
                ForEach(0..<shapes.count, id: \.self) { index in
                    Shapes.shape(
                        model: shapes[index],
                        constraints: constraints,
                        colorScheme: colorScheme
                    )
                }
            }

            if let iconModel = binding.icon {
                Icons.icon(
                    model: iconModel,
                    colorScheme: colorScheme
                )
            }
        }
    }

    func announcePage(model: PagerIndicatorModel) -> Bool {
        return model.automatedAccessibilityActions?.contains{ $0.type == .announce} ?? false
    }

    var body: some View {
        let childConstraints = ViewConstraints(
            height: constraints.height ?? 32.0
        )

        HStack(spacing: self.model.spacing) {
            ForEach(0..<self.pagerState.pages.count, id: \.self) { index in
                if self.pagerState.pageIndex == index {
                    createChild(
                        binding: self.model.bindings.selected,
                        constraints: childConstraints
                    )
                } else {
                    createChild(
                        binding: self.model.bindings.unselected,
                        constraints: childConstraints
                    )
                }
            }
        }
        .animation(.interactiveSpring(duration: Pager.animationSpeed), value: self.model)
        .constraints(constraints)
        .background(self.model.backgroundColor)
        .border(self.model.border)
        .common(self.model)

        .applyIf(announcePage(model: model), transform: { view in
            view.accessibilityLabel(String(format: "ua_pager_progress".airshipLocalizedString(), (self.pagerState.pageIndex + 1).airshipLocalizedForVoiceOver(), self.pagerState.pages.count.airshipLocalizedForVoiceOver()))
        })
    }
}
