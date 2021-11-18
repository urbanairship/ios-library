/* Copyright Airship and Contributors */

import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct BannerView: View {
    
    private static let animationInDuration = 0.2
    private static let animationOutDuration = 0.2
    
    let model: BannerPresentationModel
    let constraints: ViewConstraints
    let rootViewModel: ViewModel
    @State private var offsetPercent: CGFloat = 1.0
    
#if !os(tvOS)
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif
    
    @EnvironmentObject private var context: ThomasContext
    @EnvironmentObject private var orientationState: OrientationState
    
    var body: some View {
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
            ViewFactory.createView(model: rootViewModel, constraints: contentConstraints)
                .constraints(contentFrameConstraints)
                .margin(placement.margin)
        }
        .constraints(constraints, alignment: alignment)
        .offset(x: 0.0, y: offset * self.offsetPercent)
        .onAppear {
            displayBanner()
        }
    }
    
    private func displayBanner () {
        withAnimation(.linear(duration:BannerView.animationInDuration)) {
            self.offsetPercent = 0.0
        }
    }
    
    private func dismissBanner() {
        DispatchQueue.main.asyncAfter(deadline: .now() + BannerView.animationOutDuration) {
            context.delegate.onDismiss(buttonIdentifier: nil, cancel: false)
        }
        withAnimation(.linear(duration:BannerView.animationOutDuration)) {
            self.offsetPercent = 1.0
        }
    }
    
    private func resolvePlacement() ->  BannerPlacement {
        for placementSelector in self.model.placementSelectors ?? [] {
            if (placementSelector.windowSize != nil && placementSelector.windowSize != resolveWindowSize()) {
                continue
            }
            
            if (placementSelector.orientation != nil && placementSelector.orientation != orientationState.orientation) {
                continue
            }
            
            // its a match!
            return placementSelector.placement
        }
        
        return self.model.defaultPlacement
    }
    
    /// Uses the vertical and horizontal class size to determine small, medium, large window size:
    /// - large: regular x regular = large
    /// - medium: regular x compact or compact x regular
    /// - small: compact x compact
    func resolveWindowSize() -> WindowSize {
#if os(tvOS)
        return .large
#else
        switch(verticalSizeClass, horizontalSizeClass) {
        case (.regular, .regular):
            return .large
        case (.compact, .compact):
            return .small
        default:
            return .medium
        }
#endif
    }
}
