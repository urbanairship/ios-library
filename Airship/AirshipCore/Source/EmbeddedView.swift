/* Copyright Airship and Contributors */

import SwiftUI

/**
 * Internal only
 * :nodoc:
 */
@available(iOS 16, tvOS 16, watchOS 9.0, *)
struct AdoptLayout: SwiftUI.Layout {

    let placement: EmbeddedPlacement
    let bounds: AirshipEmbeddedViewBounds

    @Binding var viewConstraints: ViewConstraints?

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let proposed = proposal.replacingUnspecifiedDimensions()
                
        let height = placement.size.height.isFixedSize(false)
            ? placement.size.height.calculateSize(nil)
            : nil
        
        let width = placement.size.width.isFixedSize(false)
            ? placement.size.width.calculateSize(nil)
            : nil
        
        return CGSize(width: width ?? proposed.width, height: height ?? proposed.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let constraints = ConstraintsHelper.calculate(with: self.bounds, frame: bounds)

        DispatchQueue.main.async {
            viewConstraints = constraints
        }

        let proposal = ProposedViewSize(
            width: placement.size.width.isFixedSize(false) ? placement.size.width.calculateSize(nil) : proposal.width,
            height: placement.size.height.isFixedSize(false) ? placement.size.height.calculateSize(nil) : proposal.height
        )

        subviews.forEach { layout in
            layout.place(at: bounds.origin, proposal: proposal)
        }
    }
}

struct EmbeddedView: View {
    let model: EmbeddedPresentationModel
    let layout: AirshipLayout
    let thomasEnvironment: ThomasEnvironment
    let bounds: AirshipEmbeddedViewBounds

    @State private var parentSize: CGSize? = nil
    @State private var contentSize: (ViewConstraints, CGSize)? = nil
    @State private var viewConstraints: ViewConstraints?
    
    @ViewBuilder
    @MainActor
    private func makeBody(_ placement: EmbeddedPlacement) -> some View {
        if let constraints = viewConstraints {
            createView(constraints: constraints, placement: placement)
        } else {
            Color.clear
        }
    }

    var body: some View {
        RootView(thomasEnvironment: thomasEnvironment, layout: layout) { orientation, windowSize in
            let placement = resolvePlacement(
                orientation: orientation,
                windowSize: windowSize
            )

            if (placement.size.width.isPercent() || placement.size.height.isPercent()) {
                if #available(iOS 16, tvOS 16, watchOS 9.0, *) {
                    AdoptLayout(placement: placement, bounds: bounds, viewConstraints: $viewConstraints) {
                        makeBody(placement)
                    }
                    .frame(idealWidth: contentSize?.1.width, idealHeight: contentSize?.1.height)
                } else {
#if !os(watchOS)
                    LegacyLayoutWrapperView(placement: placement, bounds: bounds, viewConstraints: $viewConstraints)
                        .overlayView {
                            makeBody(placement)
                        }
                        .frame(idealWidth: contentSize?.1.width, idealHeight: contentSize?.1.height)
#endif
                }
            } else {
                let constraints = ViewConstraints(
                    width: placement.size.width.calculateSize(nil),
                    height: placement.size.height.calculateSize(nil),
                    safeAreaInsets: ViewConstraints.emptyEdgeSet
                )

                createView(constraints: constraints, placement: placement)
            }
        }
    }

    @MainActor
    private func createView(constraints: ViewConstraints, placement: EmbeddedPlacement) -> some View {
        var contentSize: CGSize?
        if constraints == self.contentSize?.0 {
            contentSize = self.contentSize?.1
        }
        
        var placementSize = placement.size
        
        if (placementSize.width.isPercent() && !self.bounds.contains(.horizontal)) {
            placementSize.width = .auto
        }

        if (placementSize.height.isPercent() && !self.bounds.contains(.vertical)) {
            placementSize.height = .auto
        }

        let contentConstraints = constraints.contentConstraints(
            placementSize,
            contentSize: contentSize,
            margin: placement.margin
        )
        
        return ViewFactory
            .createView(model: layout.view, constraints: contentConstraints)
            .background(placement.backgroundColor)
            .border(placement.border)
            .margin(placement.margin)
            .background(
                GeometryReader(content: { contentMetrics -> Color in
                    let size = contentMetrics.size
                    DispatchQueue.main.async {
                        self.contentSize = (constraints, size)
                    }
                    return Color.clear
                })
            )
    }

    private func resolvePlacement(orientation: Orientation, windowSize: WindowSize) -> EmbeddedPlacement {

        var placement = self.model.defaultPlacement
        for placementSelector in self.model.placementSelectors ?? [] {
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

//        self.viewControllerOptions.bannerPlacement = placement

        return placement
    }
}

enum ConstraintsHelper {
    static func calculate(with bounds: AirshipEmbeddedViewBounds, frame: CGRect) -> ViewConstraints {
        let width = bounds.contains(.horizontal) ? frame.width : nil
        let height = bounds.contains(.vertical) ? frame.height : nil

        return ViewConstraints(width: width, height: height, safeAreaInsets: ViewConstraints.emptyEdgeSet)
    }
}
