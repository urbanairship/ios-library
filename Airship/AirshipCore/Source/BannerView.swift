/* Copyright Airship and Contributors */

import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct BannerView: View {
    
    static let animationInDuration = 0.2
    static let animationOutDuration = 0.2
    
    let presentation: BannerPresentationModel
    let layout: Layout
    
    @ObservedObject var thomasEnvironment: ThomasEnvironment
    @Environment(\.layoutState) var layoutState
    @State private var offsetPercentWrapper = OffsetPercentWrapper()

    @Environment(\.windowSize) private var windowSize
    @Environment(\.orientation) private var orientation

    var body: some View {
        GeometryReader { metrics in
            RootView(thomasEnvironment: thomasEnvironment, layout: layout) { orientation, windowSize in
                let placement = resolvePlacement(orientation: orientation, windowSize: windowSize)
                let ignoreSafeArea = placement.ignoreSafeArea == true

                let constraints = ViewConstraints.containerConstraints(metrics.size,
                                                                       safeAreaInsets: metrics.safeAreaInsets,
                                                                       ignoreSafeArea: ignoreSafeArea)
                
                createBanner(constraints: constraints, placement: placement)
                    .applyIf(ignoreSafeArea) { $0.edgesIgnoringSafeArea(.all) }
            }
        }
    }
    
    @ViewBuilder
    private func createBanner(constraints: ViewConstraints, placement: BannerPlacement) -> some View {
        let verticalAlignment = placement.position == .top ? VerticalAlignment.top : VerticalAlignment.bottom
        let alignment = Alignment(horizontal: .center, vertical: verticalAlignment)
        let height = constraints.height ?? 0.0
        let offset = placement.position == .top ? -height : height
        
        let contentConstraints = constraints.calculateChild(placement.size)

        
        VStack {
            ViewFactory.createView(model: layout.view, constraints: contentConstraints)
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

    private func resolvePlacement(orientation: Orientation, windowSize: WindowSize) ->  BannerPlacement {
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

