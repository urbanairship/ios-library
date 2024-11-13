/* Copyright Airship and Contributors */

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif


struct BannerView: View {

    private enum PositionState {
        case hidden
        case visible
    }

    static let animationInDuration = 0.2
    static let animationOutDuration = 0.2

    let viewControllerOptions: ThomasViewControllerOptions
    let presentation: ThomasPresentationInfo.Banner
    let layout: AirshipLayout

    @ObservedObject
    var thomasEnvironment: ThomasEnvironment

    @ObservedObject
    var bannerConstraints: ThomasBannerConstraints

    /// The dimiss action callback
    let onDismiss: () -> Void


    @State private var positionState: PositionState = .hidden
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
                
                createBanner(placement: placement, metrics: metrics)
                    .airshipOnChangeOf(thomasEnvironment.isDismissed, { _ in
                        withAnimation(.linear(duration: BannerView.animationOutDuration)) {
                            self.positionState = .hidden
                        }
                        DispatchQueue.main.asyncAfter(
                            deadline: .now() + BannerView.animationOutDuration
                        ) {
                            onDismiss()
                        }
                    })
                    .onAppear {
                        withAnimation(.linear(duration: BannerView.animationInDuration)) {
                            self.positionState = .visible
                        }
                    }
            }
        }
    }

    private func createBanner(
        placement: ThomasPresentationInfo.Banner.Placement,
        metrics: GeometryProxy
    ) -> some View {
        
        let alignment = Alignment(
            horizontal: .center,
            vertical: placement.position == .top ? .top : .bottom
        )
        
        let ignoreSafeArea = placement.ignoreSafeArea == true
        let safeAreaInsets = ignoreSafeArea ? metrics.safeAreaInsets : ViewConstraints.emptyEdgeSet
        
        let constraints = ViewConstraints(
            size: self.bannerConstraints.size,
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
        
        let height = constraints.height ?? metrics.size.height

        return VStack {
            ViewFactory.createView(
                layout.view,
                constraints: contentConstraints
            )
            .thomasBackground(
                color: placement.backgroundColor,
                border: placement.border
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
        .offset(
            x: 0.0,
            y: calculateOffset(height: height, placement: placement)
        )
        .constraints(contentConstraints, alignment: alignment, fixedSize: true)
        .airshipApplyIf(ignoreSafeArea) { $0.edgesIgnoringSafeArea(.all)}
    }

    private func resolvePlacement(
        orientation: ThomasOrientation,
        windowSize: ThomasWindowSize
    ) -> ThomasPresentationInfo.Banner.Placement {

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

    private func calculateOffset(height: CGFloat, placement: ThomasPresentationInfo.Banner.Placement) -> CGFloat {
        switch(self.positionState) {
        case .hidden:
            return placement.position == .top ? -height : height
        case .visible:
            return 0
        }
    }
}
