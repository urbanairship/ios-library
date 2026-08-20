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
    @State private var constraintsPublisher = AdoptLayoutConstraintsPublisher()

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
            AdoptLayoutEngine(placement: placement, embeddedSize: embeddedSize, viewConstraints: $viewConstraints, constraintsPublisher: constraintsPublisher) {
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

/// Coalesces constraint publishes so at most one `@State` write lands per main-queue drain,
/// carrying the constraints from the drain's largest-width layout pass.
///
/// A single drain can run `placeSubviews` many times: besides the committed placement, hosts
/// that adopt content size run a width search (propose several smaller candidate widths to
/// find one whose height fits their cap). Applying constraints from a search pass makes the
/// content rigid at that width, which corrupts every subsequent measurement, re-triggers
/// layout, and can latch the content in a collapsed one-character column (observed on macOS
/// when a live window resize settles). Search passes can't be told apart from commits by
/// shape, and a drain doesn't reliably end on the commit -- but this layout is greedy (percent
/// axes adopt the full proposal), so within a drain the committed pass is always the widest.
/// Keeping the widest publish per drain therefore tracks the committed geometry both while
/// growing and while shrinking, and makes the collapsed fixed point unreachable.
@available(iOS 16, tvOS 16, watchOS 9.0, *)
@MainActor
final class AdoptLayoutConstraintsPublisher {
    private var pending: ViewConstraints?
    private var isScheduled = false

    func publish(_ constraints: ViewConstraints, to binding: Binding<ViewConstraints?>) {
        if let current = pending, isScheduled {
            let currentSize = (current.width ?? 0) + (current.height ?? 0)
            let newSize = (constraints.width ?? 0) + (constraints.height ?? 0)
            if newSize > currentSize {
                pending = constraints
            }
        } else {
            pending = constraints
        }
        guard !isScheduled else { return }
        isScheduled = true
        DispatchQueue.main.async { [self] in
            isScheduled = false
            if binding.wrappedValue != pending {
                binding.wrappedValue = pending
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
    var constraintsPublisher: AdoptLayoutConstraintsPublisher? = nil

    /// The last real proposal seen, per axis. SwiftUI also queries this layout with unspecified
    /// (nil) proposals -- notably the ideal-size pass AppKit runs when a live macOS window
    /// resize settles. A percent placement has no intrinsic ideal size, and answering the
    /// hardcoded 10pt fallback lets a size-adopting host commit that answer as real geometry,
    /// collapsing the content (and the constraints published from it) to a sliver that only
    /// recovers on the next real proposal. Remembering the last real proposal lets the
    /// ideal-size answer be "the size I already occupy".
    ///
    /// A raw proposal isn't trustworthy on its own, though -- a width search can hand this the
    /// same in-between candidate widths `constraintsPublisher` already knows to discard, and if
    /// the ideal-size query lands right after one of those (e.g. resize ends there), answering
    /// from it re-commits the discarded value. `viewConstraints` only ever holds what
    /// `constraintsPublisher` already filtered down to the widest real pass per drain, so it's
    /// preferred whenever something has actually been published; the raw last proposal is only
    /// a fallback for before that first publish exists.
    struct Cache {
        var lastRealProposalWidth: CGFloat?
        var lastRealProposalHeight: CGFloat?
    }

    func makeCache(subviews: Subviews) -> Cache {
        Cache()
    }

    private func remembered(
        _ value: CGFloat?,
        trusted: CGFloat?,
        last: inout CGFloat?
    ) -> CGFloat? {
        guard let value else { return trusted ?? last }
        if value > 0, value.isFinite {
            last = value
        }
        return value
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let proposalWidth = remembered(
            proposal.width,
            trusted: viewConstraints?.wrappedValue?.width,
            last: &cache.lastRealProposalWidth
        )
        let proposalHeight = remembered(
            proposal.height,
            trusted: viewConstraints?.wrappedValue?.height,
            last: &cache.lastRealProposalHeight
        )
        let viewSize = subviews.first?.sizeThatFits(proposal)

        let height = size(
            constraint: placement.size.height,
            minConstraint: placement.size.minHeight,
            maxConstraint: placement.size.maxHeight,
            parent: self.embeddedSize?.parentHeight,
            proposal: proposalHeight,
            sizeThataFits: viewSize?.height
        )

        let width = size(
            constraint: placement.size.width,
            minConstraint: placement.size.minWidth,
            maxConstraint: placement.size.maxWidth,
            parent: self.embeddedSize?.parentWidth,
            proposal: proposalWidth,
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

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
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
            // it's also invoked with synthetic zero proposals (same as `sizeThatFits`) to probe
            // how small this layout can go. Those probes aren't real commits; publishing from one
            // computes constraints against probe-pass bounds (e.g. 50% of a zero-width rect),
            // which changes the body and triggers another layout pass -- which gets probed again,
            // forever, or latches the content at a collapsed size a real pass never chose. A zero
            // on either axis marks a probe (a nil axis does not -- parents may legitimately place
            // with an unspecified axis), and degenerate bounds mark a pass not worth publishing;
            // constraints keep their last real value until the next committed pass.
            let isProbe = proposal.width == 0 || proposal.height == 0
            if !isProbe && bounds.width > 0 && bounds.height > 0 {
                if let constraintsPublisher {
                    MainActor.assumeIsolated {
                        constraintsPublisher.publish(newConstraints, to: viewConstraints)
                    }
                } else {
                    DispatchQueue.main.async {
                        if viewConstraints.wrappedValue != newConstraints {
                            viewConstraints.wrappedValue = newConstraints
                        }
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
        return thomasEnvironment.viewFactory
            .createView(layout.view, constraints: constraints)
            .thomasBackground(
                color: placement.backgroundColor,
                border: placement.border
            )
            .margin(placement.margin)
            .constraints(constraints)
    }
}
