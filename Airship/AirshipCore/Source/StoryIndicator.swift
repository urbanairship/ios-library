/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

struct StoryIndicator: View {

    private static let defaultSpacing = 10.0
    private static let defaultHeight = 32.0
    
    let model: StoryIndicatorModel
    let constraints: ViewConstraints

    @EnvironmentObject var pagerState: PagerState
    @Environment(\.colorScheme) var colorScheme
    
    @ViewBuilder
    private func createStoryIndicatorView(
        progressDelay: Binding<Double>,
        childConstraints: ViewConstraints
    ) -> some View {
        if (self.model.source.type == .pager) {
            
            let totalDelay = pagerState.pages.compactMap{ $0.delay }.reduce(0, +)
            GeometryReader { metrics in
                HStack(spacing: self.model.style.spacing ?? StoryIndicator.defaultSpacing) {
                    ForEach(0..<self.pagerState.pages.count, id: \.self) { index in
                        
                        let isCurrentPage = self.pagerState.pageIndex == index
                        let isCurrentPageProgressing = progressDelay.wrappedValue < 1
                        let delay = (isCurrentPage && isCurrentPageProgressing) ? progressDelay : nil
                        let currentDelay = pagerState.pages[index].delay
                        
                        createChild(
                            index: index,
                            progressDelay: delay,
                            constraints: childConstraints
                        )
                        .applyIf(self.model.style.sizing == .pageDuration) { view in
                            view.frame(
                                width: metrics.size.width * (currentDelay / totalDelay)
                            )
                        }
                    }
                }
            }
            
        } else if (self.model.source.type == .currentPage) {
            createChild(
                progressDelay: progressDelay,
                constraints: childConstraints
            )
        }
    }
    
    @ViewBuilder
    private func createChild(
        index: Int? = nil,
        progressDelay: Binding<Double>? = nil,
        constraints: ViewConstraints
    ) -> some View {
        if self.model.style.type == .linearProgress {
            Rectangle()
                .fill(indicatorColor(index))
                .overlay {
                    if let progressDelay = progressDelay {
                        GeometryReader { metrics in
                            Rectangle()
                                .frame(width: metrics.size.width * progressDelay.wrappedValue)
                                .foregroundColor(model.style.progressColor.toColor(colorScheme))
                                .animation(.linear)
                        }
                    }
                }
        }
    }
    
    var body: some View {
        let childConstraints = ViewConstraints(
            height: constraints.height ?? StoryIndicator.defaultHeight
        )

        let progress = Binding<Double> (
            get: { self.pagerState.progress },
            set: { self.pagerState.progress = $0 }
        )
        
        createStoryIndicatorView(
            progressDelay: progress,
            childConstraints: childConstraints)
        .animation(nil)
        .constraints(constraints)
        .background(self.model.backgroundColor)
        .border(self.model.border)
        .common(self.model)
    }
    
    private func indicatorColor(_ index: Int?) -> Color {
        guard let index = index else {
            return model.style.progressColor.toColor(colorScheme)
        }
        
        if pagerState.isLastPage() && pagerState.progress >= 1 {
            return model.style.progressColor.toColor(colorScheme)
        }
        
        return index < pagerState.pageIndex ? model.style.progressColor.toColor(colorScheme) : model.style.trackColor.toColor(colorScheme)
    }
}
