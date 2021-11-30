/* Copyright Airship and Contributors */

import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct ModalView: View {

    let presentation: ModalPresentationModel
    let layout: Layout
    @ObservedObject var thomasEnvironment: ThomasEnvironment
    
    @Environment(\.windowSize) private var windowSize
    @Environment(\.orientation) private var orientation

    var body: some View {
        GeometryReader { metrics in
            let placement = resolvePlacement()
            let ignoreSafeArea = placement.ignoreSafeArea == true

            let constraints = ViewConstraints.containerConstraints(metrics.size,
                                                                   safeAreaInsets: metrics.safeAreaInsets,
                                                                   ignoreSafeArea: ignoreSafeArea)
            
            createBanner(constraints: constraints, placement: placement)
                .root(thomasEnvironment)
                .applyIf(ignoreSafeArea) { $0.edgesIgnoringSafeArea(.all) }
        }
    }
    
    @ViewBuilder
    private func createBanner(constraints: ViewConstraints, placement: ModalPlacement) -> some View {
        let alignment = Alignment(horizontal: placement.position?.horizontal.toAlignment() ?? .center,
                                  vertical: placement.position?.vertical.toAlignment() ?? .center)
        
        let contentConstraints = constraints.calculateChild(placement.size,
                                                            ignoreSafeArea: placement.ignoreSafeArea)
        let contentFrameConstraints = constraints.calculateChild(placement.size,
                                                                 margin: placement.margin,
                                                                 ignoreSafeArea: placement.ignoreSafeArea)
        
        let reportingContext = ReportingContext(layoutContext: layout.reportingContext)


        VStack {
            ViewFactory.createView(model: self.layout.view, constraints: contentConstraints)
                .environment(\.reportingContext, reportingContext)
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
                        self.thomasEnvironment.dismiss(reportingContext: reportingContext)
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
