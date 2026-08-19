/* Copyright Airship and Contributors */

import SwiftUI

/// Resolves `presentation`'s placement for the current orientation/window size and adopts the
/// SwiftUI-proposed geometry for it, handing the resolved placement and `ViewConstraints` to
/// `content`. The actual layout-time geometry is only knowable inside a `Layout` conformance's
/// `placeSubviews`, so this bridges it to `content` one of two ways:
/// - Synchronously, via a nested `GeometryReader`, when placement doesn't need to measure
///   `content` itself (the common percent/points case).
/// - Via an async `@State` publish, when it does (`.auto` on either axis) -- measuring content to
///   size content is a self-referential loop that can't resolve in a single synchronous pass,
///   same reason `ModalView` still publishes its own `contentSize` asynchronously.
///
/// Which of those two paths is used is decided from every placement `presentation` could ever
/// resolve to (default + all `placementSelectors`), not just the one currently resolved, so the
/// choice stays fixed across an orientation/window-size change no matter which selector matches --
/// otherwise a scene mixing `.auto` and non-auto placements across selectors would flip branches
/// on rotation, tearing down and rebuilding `content` unnecessarily.
@available(iOS 16, tvOS 16, watchOS 9.0, *)
struct AdoptLayout<Content: View>: View {
    let placement: ThomasPresentationInfo.Embedded.Placement
    let embeddedSize: AirshipEmbeddedSize?
    let usesAutoMeasurement: Bool
    let content: (ViewConstraints, ThomasPresentationInfo.Embedded.Placement) -> Content

    @State private var viewConstraints: ViewConstraints?

    /// A presentation resolved per orientation/window size, e.g. `EmbeddedView`'s.
    init(
        presentation: ThomasPresentationInfo.Embedded,
        orientation: ThomasOrientation,
        windowSize: ThomasWindowSize,
        embeddedSize: AirshipEmbeddedSize?,
        @ViewBuilder content: @escaping (ViewConstraints, ThomasPresentationInfo.Embedded.Placement) -> Content
    ) {
        self.placement = Self.resolvePlacement(
            presentation: presentation,
            orientation: orientation,
            windowSize: windowSize
        )
        self.embeddedSize = embeddedSize
        self.usesAutoMeasurement = Self.mayResolveToAuto(presentation)
        self.content = content
    }

    private static func resolvePlacement(
        presentation: ThomasPresentationInfo.Embedded,
        orientation: ThomasOrientation,
        windowSize: ThomasWindowSize
    ) -> ThomasPresentationInfo.Embedded.Placement {
        var placement = presentation.defaultPlacement
        for placementSelector in presentation.placementSelectors ?? [] {
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

    private static func mayResolveToAuto(_ presentation: ThomasPresentationInfo.Embedded) -> Bool {
        func isAuto(_ placement: ThomasPresentationInfo.Embedded.Placement) -> Bool {
            placement.size.width.isAuto || placement.size.height.isAuto
        }

        if isAuto(presentation.defaultPlacement) {
            return true
        }

        return presentation.placementSelectors?.contains { isAuto($0.placement) } ?? false
    }

    var body: some View {
        if usesAutoMeasurement {
            AdoptLayoutEngine(placement: placement, embeddedSize: embeddedSize, viewConstraints: $viewConstraints) {
                if let viewConstraints {
                    content(viewConstraints, placement)
                } else {
                    Color.clear
                }
            }
        } else {
            AdoptLayoutEngine(placement: placement, embeddedSize: embeddedSize) {
                GeometryReader { metrics in
                    content(
                        ViewConstraints(
                            width: metrics.size.width,
                            height: metrics.size.height,
                            isHorizontalAbsoluteSize: placement.size.width.isPoints,
                            isVerticalAbsoluteSize: placement.size.height.isPoints
                        ),
                        placement
                    )
                }
            }
        }
    }
}

/// The actual `SwiftUI.Layout` conformance that resolves `placement` against the real, proposed
/// geometry. Implementation detail of `AdoptLayout` -- callers should use that instead.
@available(iOS 16, tvOS 16, watchOS 9.0, *)
private struct AdoptLayoutEngine: SwiftUI.Layout {

    let placement: ThomasPresentationInfo.Embedded.Placement
    let embeddedSize: AirshipEmbeddedSize?
    var viewConstraints: Binding<ViewConstraints?>? = nil

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let viewSize = subviews.first?.sizeThatFits(proposal)

        let height = size(
            constraint: placement.size.height,
            minConstraint: placement.size.minHeight,
            maxConstraint: placement.size.maxHeight,
            parent: self.embeddedSize?.parentHeight,
            proposal: proposal.height,
            sizeThataFits: viewSize?.height
        )

        let width = size(
            constraint: placement.size.width,
            minConstraint: placement.size.minWidth,
            maxConstraint: placement.size.maxWidth,
            parent: self.embeddedSize?.parentWidth,
            proposal: proposal.width,
            sizeThataFits: viewSize?.width
        )

        /// proposal.replacingUnspecifiedDimensions() uses `10`, so we shall as well
        return CGSize(width: width ?? 10, height: height ?? 10)
    }

    private func size(
        constraint: ThomasSizeConstraint,
        minConstraint: ThomasSizeConstraint?,
        maxConstraint: ThomasSizeConstraint?,
        parent: CGFloat?,
        proposal: CGFloat?,
        sizeThataFits: CGFloat? = nil
    ) -> CGFloat? {
        let resolved: CGFloat? = switch (constraint) {
        case .auto:
            sizeThataFits ?? proposal
        case .percent(let percent):
            if let parent = parent, parent > 0 {
                parent * percent/100.0
            } else {
                // No parent (or a degenerate zero one, e.g. the first layout pass before the
                // container's real bounds are established) to take a percentage of, so the
                // proposal is the only meaningful signal.
                // Deliberately not falling back to the child's own measurement: `constraints(_:)`
                // clamps the child to whatever this last resolved to, so reading it back forms a
                // cycle that latches the current value -- including zero, which nothing can then
                // grow back.
                proposal
            }
        case .points(let size):
            size
        }

        guard var value = resolved else { return nil }
        if let maxValue = bound(maxConstraint, parent: parent) {
            value = min(value, maxValue)
        }
        if let minValue = bound(minConstraint, parent: parent) {
            value = max(value, minValue)
        }
        return value
    }

    /// Resolves a `min`/`max` constraint to a concrete value, independent of the base
    /// `width`/`height` constraint it bounds -- e.g. `width: 100%, max_width: 100` caps a
    /// percent-based width at an absolute point value.
    private func bound(_ constraint: ThomasSizeConstraint?, parent: CGFloat?) -> CGFloat? {
        switch constraint {
        case .points(let size):
            return size
        case .percent(let percent):
            guard let parent, parent > 0 else { return nil }
            return parent * percent/100.0
        case .auto, nil:
            return nil
        }
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = size(
            constraint: placement.size.width,
            minConstraint: placement.size.minWidth,
            maxConstraint: placement.size.maxWidth,
            parent: embeddedSize?.parentWidth ?? bounds.width,
            proposal: proposal.width
        )

        let height = size(
            constraint: placement.size.height,
            minConstraint: placement.size.minHeight,
            maxConstraint: placement.size.maxHeight,
            parent: embeddedSize?.parentHeight ?? bounds.height,
            proposal: proposal.height
        )

        if let viewConstraints {
            let newConstraints = ViewConstraints(
                width: placement.size.width.isAuto ? nil : width,
                height: placement.size.height.isAuto ? nil : height,
                isHorizontalAbsoluteSize: placement.size.width.isPoints,
                isVerticalAbsoluteSize: placement.size.height.isPoints
            )

            // `placeSubviews` isn't called only once with the geometry SwiftUI committed to --
            // it's also invoked with a synthetic `.zero` proposal (same as `sizeThatFits`) to
            // probe how small this layout can go. That probe isn't a real commit; publishing it
            // would flip the constraints to 0x0, which changes the body and triggers another
            // layout pass -- which gets probed at `.zero` again, forever. Skip that degenerate case.
            if proposal.width != 0 || proposal.height != 0 {
                DispatchQueue.main.async {
                    if viewConstraints.wrappedValue != newConstraints {
                        viewConstraints.wrappedValue = newConstraints
                    }
                }
            }
        }

        let viewProposal = ProposedViewSize(width: width, height: height)

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        subviews.forEach { layout in
            layout.place(at: center, anchor: .center, proposal: viewProposal)
        }
    }
}

struct EmbeddedView: View {
    private let presentation: ThomasPresentationInfo.Embedded
    private let layout: AirshipLayout
    private let thomasEnvironment: ThomasEnvironment

    private let embeddedSize: AirshipEmbeddedSize?
    @Environment(\.isVoiceOverRunning) private var isVoiceOverRunning

    init(
        presentation: ThomasPresentationInfo.Embedded,
        layout: AirshipLayout,
        thomasEnvironment: ThomasEnvironment,
        embeddedSize: AirshipEmbeddedSize?
    ) {
        self.presentation = presentation
        self.layout = layout
        self.thomasEnvironment = thomasEnvironment
        self.embeddedSize = embeddedSize
    }

    var body: some View {
        RootView(thomasEnvironment: thomasEnvironment, layout: layout) { orientation, windowSize in
            AdoptLayout(
                presentation: presentation,
                orientation: orientation,
                windowSize: windowSize,
                embeddedSize: embeddedSize
            ) { constraints, placement in
                createView(constraints: constraints, placement: placement)
            }
        }

#if os(macOS)
        .onAppear {
            if isVoiceOverRunning {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NSAccessibility.post(
                        element: (NSApp.mainWindow ?? NSApp) as Any,
                        notification: .layoutChanged
                    )
                }
            }
        }
#elseif !os(watchOS)
        // iOS, tvOS, visionOS
        .onAppear {
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
}
