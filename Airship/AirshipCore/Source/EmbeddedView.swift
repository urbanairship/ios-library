/* Copyright Airship and Contributors */

import SwiftUI

@available(iOS 16, tvOS 16, watchOS 9.0, *)
struct AdoptLayout: SwiftUI.Layout {

    let placement: ThomasPresentationInfo.Embedded.Placement

    @Binding var viewConstraints: ViewConstraints?
    let embeddedSize: AirshipEmbeddedSize?

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let viewSize = subviews.first?.sizeThatFits(proposal)

        let height = size(
            constraint: placement.size.height,
            parent: self.embeddedSize?.parentHeight,
            proposal: proposal.height,
            sizeThataFits: viewSize?.height
        )

        let width = size(
            constraint: placement.size.width,
            parent: self.embeddedSize?.parentWidth,
            proposal: proposal.width,
            sizeThataFits: viewSize?.width
        )


        /// proposal.replacingUnspecifiedDimensions() uses `10`, so we shall as well
        let size = CGSize(width: width ?? 10, height: height ?? 10)

        let constraintWidth: CGFloat? = if placement.size.width.isAuto {
            nil
        } else {
            size.width
        }

        let constraintHeight: CGFloat? = if placement.size.height.isAuto {
            nil
        } else {
            size.height
        }

        let viewConstraints = ViewConstraints(
            width: constraintWidth,
            height: constraintHeight
        )

        DispatchQueue.main.async {
            if (self.viewConstraints != viewConstraints) {
                self.viewConstraints = viewConstraints
            }
        }

        return size
    }

    private func size(constraint: ThomasSizeConstraint, parent: CGFloat?, proposal: CGFloat?, sizeThataFits: CGFloat? = nil) -> CGFloat? {
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
        let viewProposal = ProposedViewSize(
            width: size(
                constraint: placement.size.width,
                parent: embeddedSize?.parentWidth ?? bounds.width,
                proposal: proposal.width
            ),
            height: size(
                constraint: placement.size.height,
                parent: embeddedSize?.parentHeight ?? bounds.height,
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
    let presentation: ThomasPresentationInfo.Embedded
    let layout: AirshipLayout
    let thomasEnvironment: ThomasEnvironment

    let embeddedSize: AirshipEmbeddedSize?
    @State var viewConstraints: ViewConstraints?
    @Environment(\.isVoiceOverRunning) var isVoiceOverRunning

    var body: some View {
        RootView(thomasEnvironment: thomasEnvironment, layout: layout) { orientation, windowSize in
            let placement = resolvePlacement(
                orientation: orientation,
                windowSize: windowSize
            )
            
            AdoptLayout(placement: placement, viewConstraints: $viewConstraints, embeddedSize: embeddedSize) {
                if let constraints = viewConstraints {
                    createView(constraints: constraints, placement: placement)
                } else {
                    Color.clear
                }
            }
        }
#if !os(watchOS)
        .onAppear {
            // Announce to VoiceOver when embedded view appears
            if isVoiceOverRunning {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    UIAccessibility.post(notification: .screenChanged, argument: nil)
                }
            }
        }
#endif
    }

    @MainActor
    private func createView(
        constraints: ViewConstraints,
        placement: ThomasPresentationInfo.Embedded.Placement
    ) -> some View {
        return ViewFactory
            .createView(layout.view, constraints: constraints)
            .thomasBackground(
                color: placement.backgroundColor,
                border: placement.border
            )
            .margin(placement.margin)
            .constraints(constraints)
    }

    private func resolvePlacement(
        orientation: ThomasOrientation,
        windowSize: ThomasWindowSize
    ) -> ThomasPresentationInfo.Embedded.Placement {
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

        return placement
    }
}
