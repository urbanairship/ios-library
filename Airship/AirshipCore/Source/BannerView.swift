/* Copyright Airship and Contributors */

import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct BannerView: View {
    
    let model: BannerPresentationModel
    let constraints: ViewConstraints
    let rootViewModel: ViewModel
    @State var offset: CGFloat
    
#if !os(tvOS)
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif
    
    @EnvironmentObject private var context: ThomasContext
    @EnvironmentObject private var orientationState: OrientationState
    
    var body: some View {
        let placement = resolvePlacement()
        let alignment = Alignment(horizontal: placement.position?.horizontal.toAlignment() ?? .center, vertical: placement.position?.vertical.toAlignment() ?? .center)
        
        let contentConstraints =  ViewConstraints.calculateChildConstraints(childSize: placement.size, childMargins: placement.margin,
                                                                            parentConstraints: constraints)
        VStack {
            ViewFactory.createView(model: rootViewModel, constraints: contentConstraints)
                .margin(placement.margin)
        }
        .constraints(constraints, alignment: alignment)
        .background(
            Rectangle()
                .foreground(HexColor.clear)
            /// Add tap gesture outside of view to dismiss
                .addTapGesture {
                    dismissBanner()
                }
        )
        .offset(x: 0.0, y: offset)
        .onAppear {
            displayBanner()
        }
    }
    
    private func displayBanner () {
        withAnimation(.linear(duration:Double(model.duration))) {
            self.offset = 0.0
        }
    }
    
    private func dismissBanner () {
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(model.duration)) {
            context.delegate.onDismiss(buttonIdentifier: nil, cancel: false)
        }
        withAnimation(.linear(duration:Double(model.duration))) {
            self.offset = constraints.frameHeight ?? 0.0
            
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
