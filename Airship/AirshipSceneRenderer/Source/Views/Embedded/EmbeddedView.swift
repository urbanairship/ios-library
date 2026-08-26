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
    @Environment(\.layoutDirection) private var layoutDirection

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
            AdoptLayoutEngine(placement: placement, embeddedSize: embeddedSize, layoutDirection: layoutDirection, viewConstraints: $viewConstraints, constraintsPublisher: constraintsPublisher) {
                if let viewConstraints {
                    content(viewConstraints, placement)
                } else {
                    Color.clear
                }
            }
        } else {
            AdoptLayoutEngine(placement: placement, embeddedSize: embeddedSize, layoutDirection: layoutDirection) {
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
///
/// Internal rather than fileprivate so `size(_:)` can be exercised directly: it is a pure function
/// of a placement's declared constraints and two lengths, which is where the min/max resolution
/// lives, and testing it through a hosted view instead means testing it through an async publish
/// and a run loop for no gain in coverage.
@available(iOS 16, tvOS 16, watchOS 9.0, *)
struct AdoptLayoutEngine: SwiftUI.Layout {

    let placement: ThomasPresentationInfo.Embedded.Placement
    let embeddedSize: AirshipEmbeddedSize?
    let layoutDirection: LayoutDirection
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
        // What a percentage is a share of: the space the host offered this placement. `remembered`
        // has already reduced a nil proposal to the last real one, so this is a length even on the
        // ideal-size pass.
        let widthBasis = self.embeddedSize?.parentWidth ?? proposalWidth?.safeValue
        let heightBasis = self.embeddedSize?.parentHeight ?? proposalHeight?.safeValue

        let viewSize = subviews.first?.sizeThatFits(proposal)

        let width = size(
            constraint: placement.size.width,
            minConstraint: placement.size.minWidth,
            maxConstraint: placement.size.maxWidth,
            parent: self.embeddedSize?.parentWidth,
            boundParent: widthBasis,
            proposal: proposalWidth,
            sizeThataFits: viewSize?.width
        )

        // Re-measured against the width this layout resolved, when that differs from the width the
        // content was first measured at. A narrowed width rewraps text, so a height carried over
        // from the unclamped measurement describes a layout the content will not get: with
        // `max_width: 300`, content that is one line at 390pt and two at 300pt reported a 40pt
        // height for a card that needs 80. That was merely visible overflow before anything
        // clipped; with the clip it would be a silently missing second line.
        let heightMeasurement = width == viewSize?.width
            ? viewSize?.height
            : subviews.first?.sizeThatFits(
                ProposedViewSize(width: width, height: proposalHeight)
            ).height

        let height = size(
            constraint: placement.size.height,
            minConstraint: placement.size.minHeight,
            maxConstraint: placement.size.maxHeight,
            parent: self.embeddedSize?.parentHeight,
            boundParent: heightBasis,
            proposal: proposalHeight,
            sizeThataFits: heightMeasurement
        )

        /// proposal.replacingUnspecifiedDimensions() uses `10`, so we shall as well
        return CGSize(width: width ?? 10, height: height ?? 10)
    }

    func size(
        constraint: ThomasSizeConstraint,
        minConstraint: ThomasSizeConstraint?,
        maxConstraint: ThomasSizeConstraint?,
        parent: CGFloat?,
        boundParent: CGFloat?,
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
        // `boundParent`, not `parent`. The base constraint resolves its percentage against
        // `bounds` when the host stated no parent, and has to keep doing so -- that fallback is
        // what gives a `width: 50%` placement its half. A *bound* must not, because `bounds` means
        // two different things by axis: on a percent axis this layout is greedy and reports the
        // whole proposal, so `bounds` is the host's offer; but on an auto axis it reports the
        // child's measurement, so a percentage of it is a fraction of whatever the content
        // happened to want. `max_height: 50%` on an auto axis capped the offer at half the
        // content's own height that way -- reading the child's measurement back as a constraint on
        // the child, which the comment above forbids for the same reason.
        //
        // `boundParent` is the host's offer directly, so it means one thing on every axis: the
        // space this placement was given, never anything measured from what it contains.
        if let maxValue = bound(maxConstraint, parent: boundParent) {
            value = min(value, maxValue)
        }
        if let minValue = bound(minConstraint, parent: boundParent) {
            value = max(value, minValue)
        }
        return value
    }

    /// Where to put content of a given size in a given slot: centred while it fits, and pinned to
    /// the top and the leading edge once it does not, so the overflow comes off the end.
    ///
    /// Separate and static so it can be exercised directly. The right-to-left case is the reason:
    /// it is a single term that is invisible in a screenshot and awkward to observe through a
    /// hosted view, and getting it backwards trims the start of every line instead of the end.
    static func origin(
        forContent content: CGSize,
        in bounds: CGRect,
        layoutDirection: LayoutDirection
    ) -> CGPoint {
        let x: CGFloat = if content.width > bounds.width {
            layoutDirection == .leftToRight ? bounds.minX : bounds.maxX - content.width
        } else {
            (bounds.midX - content.width / 2).safeValue ?? bounds.minX
        }

        let y: CGFloat = if content.height > bounds.height {
            bounds.minY
        } else {
            (bounds.midY - content.height / 2).safeValue ?? bounds.minY
        }

        return CGPoint(x: x, y: y)
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
            boundParent: embeddedSize?.parentWidth
                ?? proposal.width?.safeValue
                ?? cache.lastRealProposalWidth,
            proposal: proposal.width
        )

        let height = size(
            constraint: placement.size.height,
            minConstraint: placement.size.minHeight,
            maxConstraint: placement.size.maxHeight,
            parent: embeddedSize?.parentHeight ?? bounds.height,
            boundParent: embeddedSize?.parentHeight
                ?? proposal.height?.safeValue
                ?? cache.lastRealProposalHeight,
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

        // Never more than the slot this layout committed to. A bound narrows what the child is
        // offered, but on an auto axis `size()` answers `sizeThataFits ?? proposal`, and here
        // `sizeThataFits` is nil -- so an unspecified proposal leaves the offer nil and the child
        // takes its full ideal inside a slot that is smaller. That is why a `scroll_layout` in a
        // bounded placement did not scroll: nothing ever told it there was less room than its
        // content wanted. This clamp is what squeezes it. The clip is only a backstop, for content
        // that cannot be squeezed at all.
        let viewProposal = ProposedViewSize(
            width: min(width ?? bounds.width, bounds.width),
            height: min(height ?? bounds.height, bounds.height)
        )

        // Centred while the content fits its slot; once it does not, pinned per axis to the top
        // and to the leading edge so the overflow comes off the end. Content larger than its slot
        // has to lose something, and centring trims both ends at once -- cutting a headline off
        // the top and a button off the bottom of the same card. `layoutDirection` because a custom
        // `Layout`'s coordinates are not mirrored for us: in an RTL locale the content's own first
        // line sits at the right, so the trim has to come off the left instead. `Container` reads
        // the same environment for the same reason.
        subviews.forEach { layout in
            layout.place(
                at: Self.origin(
                    forContent: layout.sizeThatFits(viewProposal),
                    in: bounds,
                    layoutDirection: layoutDirection
                ),
                anchor: .topLeading,
                proposal: viewProposal
            )
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
            // A layout bounds what its child is *offered*, not what it paints. `AdoptLayoutEngine`
            // already reports `min(content, bound)` and proposes that down, but content that
            // cannot compress to it still draws at its own size -- over the host app's own views,
            // which is the reported bug. Clipping is the only thing that stops that.
            //
            // Applied out here rather than inside `AdoptLayout`: within the layout, a subview's
            // frame is its own reported size, not what it was proposed, so there is nothing to
            // clip against.
            //
            // `.contentShape` is what keeps the clip honest for touch. Clipping affects rendering
            // only -- hit testing still reaches content that is no longer drawn, so without it a
            // button clipped out of sight stays tappable through whatever the host app drew in its
            // place. VoiceOver can still reach it; that needs focus work this does not attempt.
            //
            // Unconditional, rather than gated on the placement declaring a ceiling. A slot can
            // be smaller than its content without any `max_*` at all -- `height: 50%` or a points
            // height does it too -- so a gate keyed on ceilings would leave exactly those payloads
            // trimmed to one end by `placeSubviews` and then not clipped, which is worse than the
            // centred overflow they had before. It also costs nothing here: unlike Banner and
            // Modal placements, an embedded placement declares only `margin`, `size`, `border` and
            // `backgroundColor` -- no shadow, no `ignore_safe_area` -- so there is nothing it draws
            // outside its own bounds for a clip to cut. And being unconditional, it introduces no
            // `_ConditionalContent` whose branch could flip on rotation.
            .clipped()
            .contentShape(Rectangle())
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
            // The root has no container above it to take its stroke out of its length, so it gets
            // the same deduction Banner and Modal roots do.
            .createView(layout.view, constraints: constraints.deductingBorder(of: layout.view))
            .thomasBackground(
                color: placement.backgroundColor,
                border: placement.border
            )
            .margin(placement.margin)
            .constraints(constraints)
    }
}
