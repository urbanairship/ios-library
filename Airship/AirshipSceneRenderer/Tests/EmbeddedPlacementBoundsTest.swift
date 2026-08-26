/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Testing

@testable @_spi(AirshipInternal) import AirshipSceneRenderer

/// Covers how an embedded placement's declared `min_*`/`max_*` resolve, which is the whole of
/// `AdoptLayoutEngine.size(_:)`: a pure function of the placement's constraints, the parent the
/// base resolves against, the parent a *bound* resolves against, the host's proposal, and the
/// content's own measurement.
///
/// Deliberately not written against a hosted view. An earlier version of these tests measured a
/// `UIHostingController` and every case passed while the change under test was reverted -- they
/// exercised `sizeThatFits`, and the change only altered `placeSubviews`. Calling the function
/// directly with both call shapes is what makes them able to fail.
@Suite("Embedded placement min/max bounds")
struct EmbeddedPlacementBoundsTest {

    private static func engine(
        _ size: ThomasConstrainedSize,
        embeddedSize: AirshipEmbeddedSize? = nil
    ) -> AdoptLayoutEngine {
        AdoptLayoutEngine(
            placement: ThomasPresentationInfo.Embedded.Placement(
                margin: nil,
                size: size,
                border: nil,
                backgroundColor: nil
            ),
            embeddedSize: embeddedSize,
            layoutDirection: .leftToRight
        )
    }

    private static func size(
        width: ThomasSizeConstraint = .auto,
        height: ThomasSizeConstraint = .auto,
        minWidth: ThomasSizeConstraint? = nil,
        maxWidth: ThomasSizeConstraint? = nil,
        minHeight: ThomasSizeConstraint? = nil,
        maxHeight: ThomasSizeConstraint? = nil
    ) -> ThomasConstrainedSize {
        ThomasConstrainedSize(
            minWidth: minWidth,
            width: width,
            maxWidth: maxWidth,
            minHeight: minHeight,
            height: height,
            maxHeight: maxHeight,
            aspectRatio: nil
        )
    }

    /// The `sizeThatFits` call shape: the content has been measured, and a bound resolves against
    /// the host's offer.
    private static func measuring(
        _ constrained: ThomasConstrainedSize,
        content: CGFloat?,
        offer: CGFloat?,
        statedParent: CGFloat? = nil
    ) -> CGFloat? {
        engine(constrained, embeddedSize: statedParent.map { AirshipEmbeddedSize(parentHeight: $0) })
            .size(
                constraint: constrained.height,
                minConstraint: constrained.minHeight,
                maxConstraint: constrained.maxHeight,
                parent: statedParent,
                boundParent: statedParent ?? offer,
                proposal: offer,
                sizeThataFits: content
            )
    }

    /// The `placeSubviews` call shape: no measurement in hand, and the base falls back to the
    /// committed slot while a bound still resolves against the host's offer.
    private static func placing(
        _ constrained: ThomasConstrainedSize,
        slot: CGFloat,
        offer: CGFloat?,
        statedParent: CGFloat? = nil
    ) -> CGFloat? {
        engine(constrained, embeddedSize: statedParent.map { AirshipEmbeddedSize(parentHeight: $0) })
            .size(
                constraint: constrained.height,
                minConstraint: constrained.minHeight,
                maxConstraint: constrained.maxHeight,
                parent: statedParent ?? slot,
                boundParent: statedParent ?? offer,
                proposal: offer,
                sizeThataFits: nil
            )
    }

    // MARK: - points bounds

    @Test("a points ceiling caps content taller than it, on both passes")
    func pointsCeilingCaps() {
        let s = Self.size(height: .auto, maxHeight: .points(300))
        #expect(Self.measuring(s, content: 600, offer: 800) == 300)
        #expect(Self.placing(s, slot: 300, offer: 800) == 300)
    }

    @Test("a points ceiling leaves shorter content alone")
    func pointsCeilingHugs() {
        let s = Self.size(height: .auto, maxHeight: .points(300))
        // An auto axis that declares a ceiling is still an auto axis.
        #expect(Self.measuring(s, content: 80, offer: 800) == 80)
    }

    @Test("a points floor stretches shorter content up to it")
    func pointsFloorStretches() {
        let s = Self.size(height: .auto, minHeight: .points(250))
        #expect(Self.measuring(s, content: 80, offer: 800) == 250)
    }

    // MARK: - percent bounds resolve against the host's offer, not the slot

    @Test("a percent ceiling on an auto axis is a share of the host offer, not of the content")
    func percentCeilingOnAutoAxis() {
        let s = Self.size(height: .auto, maxHeight: .percent(50))
        // 50% of the 800 offered. Resolving against the content's own 600 would give 300, which is
        // what `bounds` yielded before: a constraint derived from the thing it constrains.
        #expect(Self.measuring(s, content: 600, offer: 800) == 400)
        #expect(Self.placing(s, slot: 400, offer: 800) == 400)
    }

    @Test("a percent ceiling is enforced with no AirshipEmbeddedSize")
    func percentCeilingNeedsNoStatedParent() {
        let s = Self.size(height: .auto, maxHeight: .percent(50))
        #expect(Self.measuring(s, content: 600, offer: 800, statedParent: nil) == 400)
    }

    @Test("a percent ceiling honours a stated parent over the offer")
    func percentCeilingPrefersStatedParent() {
        let s = Self.size(height: .auto, maxHeight: .percent(50))
        // The host is authoritative about its own parent -- inside a scroll view the offer is not
        // the parent at all.
        #expect(Self.measuring(s, content: 600, offer: 2000, statedParent: 800) == 400)
    }

    @Test("a percent ceiling still caps a percent base")
    func percentCeilingCapsPercentBase() {
        // The cell the reviewed change regressed: base 100% of a 390 offer is 390, and a 50%
        // ceiling has to bring it to 195. Resolving the bound against nothing left it at 390.
        let s = Self.size(height: .percent(100), maxHeight: .percent(50))
        #expect(Self.placing(s, slot: 390, offer: 390) == 195)
        #expect(Self.measuring(s, content: 600, offer: 390) == 195)
    }

    @Test("a percent base with no bounds keeps its declared share")
    func percentBaseUnbounded() {
        let s = Self.size(height: .percent(50))
        // The `?? slot` fallback for the BASE has to survive: this is what gives a percent
        // placement its fraction when the host stated no parent.
        #expect(Self.placing(s, slot: 400, offer: 400) == 200)
    }

    @Test("a points base is capped by a percent ceiling")
    func pointsBaseWithPercentCeiling() {
        let s = Self.size(height: .points(300), maxHeight: .percent(50))
        #expect(Self.placing(s, slot: 300, offer: 400) == 200)
        #expect(Self.placing(s, slot: 300, offer: 1000) == 300)
    }

    // MARK: - malformed payloads

    @Test("min above max resolves min-wins")
    func minAboveMaxResolvesMinWins() {
        let s = Self.size(height: .auto, minHeight: .points(400), maxHeight: .points(200))
        // `size()` clamps with the max first and the min second, so the min survives.
        #expect(Self.measuring(s, content: 80, offer: 800) == 400)
        #expect(Self.placing(s, slot: 400, offer: 800) == 400)
    }

    @Test("an unspecified offer leaves a percent bound unresolved rather than guessing")
    func percentBoundWithNoOffer() {
        let s = Self.size(height: .auto, maxHeight: .percent(50))
        // Nothing exogenous to take a share of. Reporting the content unbounded beats inventing a
        // ceiling from the content's own extent.
        #expect(Self.measuring(s, content: 600, offer: nil) == 600)
    }

    @Test("declaring no bounds returns the content's own measurement")
    func unbounded() {
        let s = Self.size(height: .auto)
        #expect(Self.measuring(s, content: 137, offer: 800) == 137)
    }
}

#if canImport(UIKit)

import UIKit

/// What the placement does to the content *below* it: what the content is offered, where it is
/// placed when it overflows, and whether a narrowed width is measured before the height is taken.
///
/// These need a real layout pass, so they host the view and wait for `AdoptLayout`'s async
/// constraints publish. The content is a `Layout` that records every proposal it receives and
/// reports whatever size it is told to, which is how an incompressible card behaves -- and the
/// recorded proposals are the thing under test, not the reported size.
@Suite("Embedded placement bounds, through a layout pass", .serialized)
@MainActor
struct EmbeddedPlacementBoundsLayoutPassTest {

    private final class Probe: @unchecked Sendable {
        var proposals: [ProposedViewSize] = []
        var placedAt: [CGPoint] = []
        /// Height to report, as a function of the width offered -- a stand-in for text rewrapping.
        var heightForWidth: (CGFloat?) -> CGFloat = { _ in 600 }
        var reportedWidth: CGFloat = 200
    }

    private struct ProbeLayout: SwiftUI.Layout {
        let probe: Probe

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            probe.proposals.append(proposal)
            return CGSize(
                width: probe.reportedWidth,
                height: probe.heightForWidth(proposal.width)
            )
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            probe.placedAt.append(bounds.origin)
        }
    }

    private static func run(
        size: String,
        probe: Probe,
        insideScrollView: Bool = false,
        layoutDirection: LayoutDirection = .leftToRight,
        hostOffer: CGSize = CGSize(width: 390, height: 800)
    ) async throws -> CGSize {
        let presentation = try JSONDecoder().decode(
            ThomasPresentationInfo.Embedded.self,
            from: Data("""
            {"type": "embedded", "embedded_id": "test", "default_placement": {"size": \(size)}}
            """.utf8)
        )

        let placement = AdoptLayout(
            presentation: presentation,
            orientation: .portrait,
            windowSize: .medium,
            embeddedSize: nil
        ) { _, _ in
            ProbeLayout(probe: probe) { Color.clear }
        }

        let root = AnyView(
            Group {
                if insideScrollView {
                    // Proposes an unspecified height, the case a bounded placement has to survive:
                    // `size()` answers nil there, so without the clamp the content is never told it
                    // has less room than it wants.
                    ScrollView { placement }
                } else {
                    placement
                }
            }
            .environment(\.layoutDirection, layoutDirection)
        )

        let controller = UIHostingController(rootView: root)
        controller.safeAreaRegions = []
        let window = UIWindow(frame: CGRect(origin: .zero, size: hostOffer))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.frame = CGRect(origin: .zero, size: hostOffer)
        controller.view.layoutIfNeeded()

        for _ in 0..<8 {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 20_000_000)
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
        }

        let measured = controller.sizeThatFits(in: hostOffer)
        window.isHidden = true
        window.rootViewController = nil
        return measured
    }

    @Test("inside a scroll view, a ceilinged placement still offers its content only the slot")
    func clampsOfferToSlotUnderUnspecifiedProposal() async throws {
        let probe = Probe()
        _ = try await Self.run(
            size: #"{"width": "100%", "height": "auto", "max_height": 300}"#,
            probe: probe,
            insideScrollView: true
        )

        // The offer that matters is the narrowest real one the content ever saw. Without the clamp
        // this is nil -- an unspecified height -- and a scroll_layout inside takes its full ideal
        // instead of scrolling.
        let offers = probe.proposals.compactMap(\.height)
        #expect(offers.contains { $0 <= 300 })
        #expect(probe.proposals.contains { $0.height != nil })
    }

    @Test("height is measured at the width the placement resolved, not the width it was offered")
    func remeasuresHeightAtResolvedWidth() async throws {
        let probe = Probe()
        probe.reportedWidth = 390
        // One line at the full offer, two lines once the width is capped -- what text does.
        probe.heightForWidth = { width in (width ?? 390) >= 390 ? 40 : 80 }

        let measured = try await Self.run(
            size: #"{"width": "100%", "height": "auto", "max_width": 300}"#,
            probe: probe
        )

        // 80, not 40: the height has to come from a measurement taken at 300pt wide. Reporting 40
        // would clip the second line away with no visual cue.
        #expect(measured.height == 80)
    }

    @Test("overflow is trimmed from the trailing edge, mirrored for right-to-left")
    func trimsFromTheTrailingEdge() {
        let slot = CGRect(x: 0, y: 0, width: 390, height: 200)
        let overflowing = CGSize(width: 500, height: 100)

        let ltr = AdoptLayoutEngine.origin(
            forContent: overflowing, in: slot, layoutDirection: .leftToRight
        )
        let rtl = AdoptLayoutEngine.origin(
            forContent: overflowing, in: slot, layoutDirection: .rightToLeft
        )

        // 500pt of content in a 390pt slot. Left-to-right keeps the start of the line and loses
        // the right. Right-to-left has to keep the right, where the line begins, so the content
        // hangs off to the left instead.
        #expect(ltr.x == 0)
        #expect(rtl.x == -110)
        // Vertically it fits, so both centre it.
        #expect(ltr.y == 50)
        #expect(rtl.y == 50)
    }

    @Test("content that fits is centred on both axes, in either direction")
    func centresContentThatFits() {
        let slot = CGRect(x: 0, y: 0, width: 390, height: 200)
        let fitting = CGSize(width: 200, height: 100)

        for direction in [LayoutDirection.leftToRight, .rightToLeft] {
            let origin = AdoptLayoutEngine.origin(
                forContent: fitting, in: slot, layoutDirection: direction
            )
            #expect(origin == CGPoint(x: 95, y: 50))
        }
    }

    @Test("over-tall content keeps its top")
    func overTallContentKeepsItsTop() {
        let origin = AdoptLayoutEngine.origin(
            forContent: CGSize(width: 200, height: 600),
            in: CGRect(x: 0, y: 0, width: 390, height: 300),
            layoutDirection: .leftToRight
        )
        // Not -150: centring would cut a headline off the top and a button off the bottom at once.
        #expect(origin.y == 0)
    }

    @Test("a non-finite measurement falls back to the slot origin rather than placing at NaN")
    func nonFiniteMeasurementIsGuarded() {
        let origin = AdoptLayoutEngine.origin(
            forContent: CGSize(width: CGFloat.nan, height: CGFloat.nan),
            in: CGRect(x: 0, y: 0, width: 390, height: 300),
            layoutDirection: .leftToRight
        )
        #expect(origin.x == 0)
        #expect(origin.y == 0)
    }
}

#endif
