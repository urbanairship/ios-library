/* Copyright Airship and Contributors */

import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct ModalView: View {

    let presentation: ModalPresentationModel
    let layout: Layout
    @ObservedObject var thomasEnvironment: ThomasEnvironment
    let viewControllerOptions: ThomasViewControllerOptions

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
    private func createBanner(constraints: ViewConstraints, placement: ModalPlacement) -> some View {
        let alignment = Alignment(horizontal: placement.position?.horizontal.toAlignment() ?? .center,
                                  vertical: placement.position?.vertical.toAlignment() ?? .center)
        
        let contentConstraints = constraints.calculateChild(placement.size,
                                                            ignoreSafeArea: placement.ignoreSafeArea)

        VStack {
            ViewFactory.createView(model: self.layout.view, constraints: contentConstraints)
                .margin(placement.margin)
        }
        .constraints(constraints, alignment: alignment)
        .background(
            Rectangle()
                .foreground(placement.shade)
                .edgesIgnoringSafeArea(.all)
                .applyIf(self.presentation.dismissOnTouchOutside == true) { view in
                    // Add tap gesture outside of view to dismiss
                    view.addTapGesture {
                        self.thomasEnvironment.dismiss()
                    }
                }
        )
    }
    

    
    private func resolvePlacement(orientation: Orientation, windowSize: WindowSize) -> ModalPlacement {
        var placement = self.presentation.defaultPlacement
        
        let resolvedOrientation = viewControllerOptions.orientation ?? orientation
        for placementSelector in self.presentation.placementSelectors ?? [] {
            if (placementSelector.windowSize != nil && placementSelector.windowSize != windowSize) {
                continue
            }
            
            if (placementSelector.orientation != nil && placementSelector.orientation != resolvedOrientation) {
                continue
            }
            
            // its a match!
            placement = placementSelector.placement
            break
        }
    
        self.viewControllerOptions.orientation = placement.device?.orientationLock
        return placement
    }
}
