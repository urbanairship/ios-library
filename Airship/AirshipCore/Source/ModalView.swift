/* Copyright Airship and Contributors */

import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct ModalView: View {

    let presentation: ModalPresentationModel
    let view: ViewModel
    let context: ThomasContext
    
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
        let alignment = Alignment(horizontal: placement.position?.horizontal.toAlignment() ?? .center,
                                  vertical: placement.position?.vertical.toAlignment() ?? .center)
        
        let contentConstraints =  ViewConstraints.calculateChildConstraints(childSize: placement.size,
                                                                            parentConstraints: constraints)
        
        let contentFrameConstraints = ViewConstraints.calculateChildConstraints(childSize: placement.size,
                                                                              parentConstraints: constraints,
                                                                              childMargins: placement.margin)
        VStack {
            ViewFactory.createView(model: self.view, constraints: contentConstraints)
                .constraints(contentFrameConstraints)
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
                        context.delegate.onDismiss(buttonIdentifier: nil, cancel: false)
                    }
                }
        )
    }
    
    private func resolvePlacement() ->  ModalPlacement {
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
}
