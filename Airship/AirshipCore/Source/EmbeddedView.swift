/* Copyright Airship and Contributors */

import SwiftUI

@available(iOS 16, tvOS 16, watchOS 9.0, *)
struct AdoptLayout: SwiftUI.Layout {

    let placement: EmbeddedPlacement

    @Binding var viewConstraints: ViewConstraints?
    let embeddedSize: AirshipEmbeddedSize?

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let viewSize = subviews.first?.sizeThatFits(proposal)

        let height = size(
            constraint: placement.size.height,
            parent: self.embeddedSize?.maxHeight,
            proposal: proposal.height,
            sizeThataFits: viewSize?.height
        )

        let width = size(
            constraint: placement.size.width,
            parent: self.embeddedSize?.maxWidth,
            proposal: proposal.width,
            sizeThataFits: viewSize?.width
        )


        /// proposal.replacingUnspecifiedDimensions() uses `10`, so we shall as well
        let size = CGSize(width: width ?? 10, height: height ?? 10)
        return size
    }

    private func size(constraint: SizeConstraint, parent: CGFloat?, proposal: CGFloat?, sizeThataFits: CGFloat? = nil) -> CGFloat? {
        switch (constraint) {
        case .auto:
            return sizeThataFits ?? proposal
        case .percent(let percent):
            if let parent = parent {
                return parent * percent/100.0
            }
            return proposal ?? sizeThataFits
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
    @State var viewConstraints: ViewConstraints?

    var body: some View {
        RootView(thomasEnvironment: thomasEnvironment, layout: layout) { orientation, windowSize in
            let placement = resolvePlacement(
                orientation: orientation,
                windowSize: windowSize
            )

            if #available(iOS 16, tvOS 16, watchOS 9.0, *) {
                AdoptLayout(placement: placement, viewConstraints: $viewConstraints, embeddedSize: embeddedSize) {
                    if let constraints = viewConstraints {
                        createView(constraints: constraints, placement: placement)
                    } else {
                        Color.clear
                    }
                }
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
        let contentConstraints = constraints.contentConstraints(
            placement.size,
            contentSize: nil,
            margin: placement.margin
        )

        return ViewFactory
            .createView(model: layout.view, constraints: contentConstraints)
            .background(placement.backgroundColor)
            .border(placement.border)
            .margin(placement.margin)
            .constraints(contentConstraints)
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
