/* Copyright Airship and Contributors */

import SwiftUI

/**
 * Internal only
 * :nodoc:
 */
@available(iOS 16, tvOS 16, watchOS 9.0, *)
struct AdoptLayout: SwiftUI.Layout {

    let placement: EmbeddedPlacement

    @Binding var viewConstraints: ViewConstraints?
    let embeddedSize: AirshipEmbeddedSize?

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let height = size(
            constraint: placement.size.height,
            parent: self.embeddedSize?.maxHeight,
            proposal: proposal.height
        )

        let width = size(
            constraint: placement.size.width,
            parent: self.embeddedSize?.maxWidth,
            proposal: proposal.width
        )

        let size = CGSize(width: width, height: height)

        return size
    }

    private func size(constraint: SizeConstraint, parent: CGFloat?, proposal: CGFloat?) -> CGFloat {
        switch (constraint) {
        case .auto:
            return 0
        case .percent(_):
            return parent ?? proposal ?? 10.0
        case .points(let size):
            return size
        }
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let constraints = ViewConstraints(
            width: embeddedSize?.maxWidth ?? bounds.width,
            height: embeddedSize?.maxHeight ?? bounds.height
        )

        DispatchQueue.main.async {
            viewConstraints = constraints
        }

        let viewProposal = ProposedViewSize(
            width: size(
                constraint: placement.size.width,
                parent: embeddedSize?.maxWidth ?? bounds.width,
                proposal: proposal.width
            ),
            height: size(
                constraint: placement.size.height,
                parent: embeddedSize?.maxHeight ?? bounds.height,
                proposal: proposal.height
            )
        )

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        subviews.forEach { layout in
            layout.place(at: center, anchor: .center, proposal: viewProposal)
        }
    }
}

struct EmbeddedView: View {
    let model: EmbeddedPresentationModel
    let layout: AirshipLayout
    let thomasEnvironment: ThomasEnvironment

    let embeddedSize: AirshipEmbeddedSize?
    @State private var contentSize: (ViewConstraints, CGSize)? = nil
    @State var viewConstraints: ViewConstraints?
    
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

            if #available(iOS 16, tvOS 16, watchOS 9.0, *) {
                AdoptLayout(placement: placement, viewConstraints: $viewConstraints, embeddedSize: embeddedSize) {
                    makeBody(placement)
                }
                .frame(idealWidth: contentSize?.1.width, idealHeight: contentSize?.1.height)
            } else {
                let constraints = ViewConstraints(
                    width: placement.size.width.calculateSize(self.embeddedSize?.maxWidth),
                    height: placement.size.height.calculateSize(self.embeddedSize?.maxHeight)
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

        let contentConstraints = constraints.contentConstraints(
            placement.size,
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
            .onAppear {
                self.thomasEnvironment.onAppear()
            }
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

        return placement
    }
}
