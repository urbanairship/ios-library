/* Copyright Airship and Contributors */

import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct BannerView: View {
    
    static let animationInDuration = 0.2
    static let animationOutDuration = 0.2
    
    let presentation: BannerPresentationModel
    let view: ViewModel
    let context: ThomasContext
    
    @ObservedObject private var offsetPercentWrapper = OffsetPercentWrapper()

    @Environment(\.windowSize) private var windowSize
    @Environment(\.orientation) private var orientation

    var body: some View {
        GeometryReader { metrics in
            let constraints = ViewConstraints(width: metrics.size.width,
                                              height: metrics.size.height)
            
            createBanner(constraints: constraints)
                .root(context: context)
        }
    }
    
    @ViewBuilder
    private func createBanner(constraints: ViewConstraints) -> some View {
        let placement = resolvePlacement()
        let verticalAlignment = placement.position == .top ? VerticalAlignment.top : VerticalAlignment.bottom
        let alignment = Alignment(horizontal: .center, vertical: verticalAlignment)
        let height = constraints.height ?? 0.0
        let offset = placement.position == .top ? -height : height
        
        let contentConstraints =  ViewConstraints.calculateChildConstraints(childSize: placement.size,
                                                                            parentConstraints: constraints)
        
        let contentFrameConstraints = ViewConstraints.calculateChildConstraints(childSize: placement.size,
                                                                              parentConstraints: constraints,
                                                                              childMargins: placement.margin)
        VStack {
            ViewFactory.createView(model: view, constraints: contentConstraints)
                .constraints(contentFrameConstraints)
                .margin(placement.margin)
                .shadow(radius: 5)
        }
        .constraints(constraints, alignment: alignment)
        .offset(x: 0.0, y: offset * self.offsetPercentWrapper.offsetPercent)
        .onAppear {
            displayBanner()
        }
    }
    
    private func displayBanner () {
        withAnimation(.linear(duration: BannerView.animationInDuration)) {
            self.offsetPercentWrapper.offsetPercent = 0.0
        }
    }
    
    func dismiss(onComplete: @escaping () -> Void) {
        withAnimation(.linear(duration: BannerView.animationOutDuration)) {
            self.offsetPercentWrapper.offsetPercent = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + BannerView.animationOutDuration) {
            onComplete()
        }
    }

    private func resolvePlacement() ->  BannerPlacement {
        for placementSelector in self.presentation.placementSelectors ?? [] {
            if (placementSelector.windowSize != nil && placementSelector.windowSize != windowSize) {
                continue
            }
            
            if (placementSelector.orientation != nil && placementSelector.orientation != orientation) {
                continue
            }
            
            // its a match!
            return placementSelector.placement
        }
        
        return self.presentation.defaultPlacement
    }
    
    @available(iOS 13.0.0, tvOS 13.0, *)
    private class OffsetPercentWrapper: ObservableObject {
        @Published var offsetPercent: Double = 1.0
    }
        
}

