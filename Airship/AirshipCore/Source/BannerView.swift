/* Copyright Airship and Contributors */

import SwiftUI

struct BannerView: View {

    static let animationInDuration = 0.2
    static let animationOutDuration = 0.2

    let viewControllerOptions: ThomasViewControllerOptions
    let presentation: BannerPresentationModel
    let layout: Layout

    @ObservedObject
    var thomasEnvironment: ThomasEnvironment

    @State private var offsetPercentWrapper = OffsetPercentWrapper()
    @State private var contentSize: (ViewConstraints, CGSize)? = nil

    @Environment(\.layoutState) var layoutState
    @Environment(\.windowSize) private var windowSize
    @Environment(\.orientation) private var orientation

    var body: some View {
        GeometryReader { metrics in
            RootView(
                thomasEnvironment: thomasEnvironment,
                layout: layout
            ) { orientation, windowSize in
                let placement = resolvePlacement(
                    orientation: orientation,
                    windowSize: windowSize
                )
                
                #if !os(watchOS)
                createBanner(placement: placement, metrics: metrics)
                #endif
            }
        }
    }

    private func createBanner(
        placement: BannerPlacement,
        metrics: GeometryProxy
    ) -> some View {
        
        let alignment = Alignment(
            horizontal: .center,
            vertical: placement.position == .top ? .top : .bottom
        )
        
        let ignoreSafeArea = placement.ignoreSafeArea == true
        let safeAreaInsets = ignoreSafeArea ? metrics.safeAreaInsets : ViewConstraints.emptyEdgeSet
        
        let constraints = ViewConstraints(
            size: UIScreen.main.bounds.size,
            safeAreaInsets: safeAreaInsets
        )
        
        var contentSize: CGSize?
        if constraints == self.contentSize?.0 {
            contentSize = self.contentSize?.1
        }

        let contentConstraints = constraints.contentConstraints(
            placement.size,
            contentSize: contentSize,
            margin: placement.margin
        )
        
        let height = constraints.height ?? 0.0
        let offset = placement.position == .top ? -height : height
        
        return VStack {
            ViewFactory.createView(
                model: layout.view,
                constraints: contentConstraints
            )
            .margin(placement.margin)
            .shadow(radius: 5)
            .background(
                GeometryReader(content: { contentMetrics -> Color in
                    let size = contentMetrics.size
                    DispatchQueue.main.async {
                        self.contentSize = (constraints, size)
                        self.viewControllerOptions.bannerSize = size
                    }
                    return Color.clear
                })
            )
        }
        .constraints(contentConstraints, alignment: alignment, fixedSize: true)
        .offset(x: 0.0, y: offset * self.offsetPercentWrapper.offsetPercent)
        .applyIf(ignoreSafeArea) { $0.edgesIgnoringSafeArea(.all)}
        .onAppear {
            displayBanner()
        }
    }

    private func displayBanner() {
        withAnimation(.linear(duration: BannerView.animationInDuration)) {
            self.offsetPercentWrapper.offsetPercent = 0.0
        }
    }

    func dismiss(onComplete: @escaping () -> Void) {
        withAnimation(.linear(duration: BannerView.animationOutDuration)) {
            self.offsetPercentWrapper.offsetPercent = 1.0
        }

        DispatchQueue.main.asyncAfter(
            deadline: .now() + BannerView.animationOutDuration
        ) {
            onComplete()
        }
    }

    private func resolvePlacement(
        orientation: Orientation,
        windowSize: WindowSize
    ) -> BannerPlacement {

        var placement = self.presentation.defaultPlacement
        for placementSelector in self.presentation.placementSelectors ?? [] {
            if placementSelector.windowSize != nil
                && placementSelector.windowSize != windowSize
            {
                continue
            }

            if placementSelector.orientation != nil
                && placementSelector.orientation != orientation
            {
                continue
            }

            // its a match!
            placement = placementSelector.placement
        }

        self.viewControllerOptions.bannerPlacement = placement

        return placement
    }
    
    private class OffsetPercentWrapper: ObservableObject {
        @Published var offsetPercent: Double = 1.0
    }

}
