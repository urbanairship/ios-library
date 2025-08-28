/* Copyright Airship and Contributors */


import SwiftUI

struct StoryIndicator: View {

    private static let defaultSpacing = 10.0
    private static let defaultHeight = 32.0
    
    let info: ThomasViewInfo.StoryIndicator
    let constraints: ViewConstraints

    @EnvironmentObject var pagerState: PagerState
    @Environment(\.colorScheme) var colorScheme
    
    func announcePage(info: ThomasViewInfo.StoryIndicator) -> Bool {
        return info.properties.automatedAccessibilityActions?.contains{ $0.type == .announce} ?? false
    }

    var style: ThomasViewInfo.StoryIndicator.Style.LinearProgress {
        switch (self.info.properties.style) {
        case .linearProgress(let style): return style
        }
    }

    @ViewBuilder
    private func createStoryIndicatorView(
        progressDelay: Binding<Double>,
        childConstraints: ViewConstraints
    ) -> some View {
        if (self.info.properties.source.type == .pager) {

            let totalDelay = pagerState.pageStates.compactMap{ $0.delay }.reduce(0, +)
            GeometryReader { metrics in
                HStack(spacing: style.spacing ?? StoryIndicator.defaultSpacing) {
                    ForEach(0..<self.pagerState.pageStates.count, id: \.self) { index in
                        
                        let isCurrentPage = self.pagerState.pageIndex == index
                        let isCurrentPageProgressing = progressDelay.wrappedValue < 1
                        let delay = (isCurrentPage && isCurrentPageProgressing) ? progressDelay : nil
                        let currentDelay = pagerState.pageStates[index].delay
                        
                        createChild(
                            index: index,
                            progressDelay: delay,
                            constraints: childConstraints
                        )
                        .airshipApplyIf(self.style.sizing == .pageDuration) { view in
                            view.frame(
                                width: metrics.size.width * (currentDelay / totalDelay)
                            )
                        }
                    }
                }.airshipApplyIf(announcePage(info: info), transform: { view in
                    view.accessibilityLabel(String(format: "ua_pager_progress".airshipLocalizedString(), (self.pagerState.pageIndex + 1).airshipLocalizedForVoiceOver(), self.pagerState.pageStates.count.airshipLocalizedForVoiceOver()))
                })
            }
            
        } else if (self.info.properties.source.type == .currentPage) {
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
        Rectangle()
            .fill(indicatorColor(index))
            .airshipApplyIf(progressDelay == nil) { view in
                view.frame(height: (constraints.height ?? StoryIndicator.defaultHeight) * 0.5) }
            .overlayView {
                if let progressDelay = progressDelay {
                    GeometryReader { metrics in
                        Rectangle()
                            .frame(width: metrics.size.width * progressDelay.wrappedValue)
                            .foregroundColor(self.style.progressColor.toColor(colorScheme))
                            .animation(.linear(duration: Pager.animationSpeed), value: self.info)
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
        .animation(nil, value: self.info)
        .constraints(constraints)
        .thomasCommon(self.info)
    }
    
    private func indicatorColor(_ index: Int?) -> Color {
        guard let index = index else {
            return self.style.progressColor.toColor(colorScheme)
        }
        
        if pagerState.completed && pagerState.progress >= 1 {
            return self.style.progressColor.toColor(colorScheme)
        }
        
        return index < pagerState.pageIndex ? self.style.progressColor.toColor(colorScheme) : self.style.trackColor.toColor(colorScheme)
    }
}
