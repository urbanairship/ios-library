/* Copyright Airship and Contributors */

#if !os(macOS) && !os(watchOS)

import CoreGraphics
import SwiftUI
import Testing
import UIKit

@testable import AirshipSceneRenderer

/// Covers `thomasParallaxBackgrounds`'s actual motion math by sampling real rendered positions,
/// not just confirming it compiles: a layer's offset is `factor * contentOffset`, and it must
/// stay oversized enough to cover the frame at the far end of `maxTravel` without a gap.
@MainActor
struct BackgroundParallaxTest {

    private func layers(factor: Double) throws -> [ThomasParallaxBackgroundLayer] {
        try JSONDecoder().decode([ThomasParallaxBackgroundLayer].self, from: Data("""
            [{
                "type": "color",
                "color": { "default": { "hex": "#FF0000", "alpha": 1 } },
                "parallax": { "factor": \(factor) }
            }]
            """.utf8))
    }

    /// A sharp red|blue step at the oversized layer's midpoint, so any displacement shows.
    private func stepLayers(factor: Double) throws -> [ThomasParallaxBackgroundLayer] {
        try JSONDecoder().decode([ThomasParallaxBackgroundLayer].self, from: Data("""
            [{
                "type": "gradient",
                "gradient": {
                    "style": "linear",
                    "angle": 90,
                    "stops": [
                        { "color": { "default": { "hex": "#FF0000", "alpha": 1 } }, "position": 0 },
                        { "color": { "default": { "hex": "#FF0000", "alpha": 1 } }, "position": 0.4999 },
                        { "color": { "default": { "hex": "#0000FF", "alpha": 1 } }, "position": 0.5001 },
                        { "color": { "default": { "hex": "#0000FF", "alpha": 1 } }, "position": 1 }
                    ]
                },
                "parallax": { "factor": \(factor) }
            }]
            """.utf8))
    }

    /// `factor: 0` -- the layer must sit in the exact same place regardless of how far the real
    /// content has moved, since it's pinned.
    @Test
    func zeroFactorNeverMoves() throws {
        let width = 200.0
        let height = 20.0
        let base = Color.clear.frame(width: width, height: height)
        let pinned = try layers(factor: 0)

        let atRest = try #require(renderPixels(
            base.thomasParallaxBackgrounds(pinned, axis: .horizontal, contentOffset: 0, maxTravel: 100),
            size: CGSize(width: width, height: height)
        ))
        let midTravel = try #require(renderPixels(
            base.thomasParallaxBackgrounds(pinned, axis: .horizontal, contentOffset: -80, maxTravel: 100),
            size: CGSize(width: width, height: height)
        ))

        #expect(atRest == midTravel, "a factor: 0 layer must render identically no matter how far the content offset moves")
    }

    /// `factor: 1` at the far end of `maxTravel`: the layer is oversized enough that the frame's
    /// trailing edge stays covered. The base is transparent so it can't mask a gap.
    @Test
    func fullTravelStillCoversTrailingEdgeWithNoGap() throws {
        let width = 200.0
        let height = 20.0
        let maxTravel = 100.0
        let base = Color.clear.frame(width: width, height: height)
        let full = try layers(factor: 1)

        let buffer = try #require(renderPixels(
            base.thomasParallaxBackgrounds(full, axis: .horizontal, contentOffset: -maxTravel, maxTravel: maxTravel),
            size: CGSize(width: width, height: height)
        ))

        let trailingEdge = pixel(buffer, width: Int(width), x: Int(width) - 1, y: Int(height) / 2)

        #expect(trailingEdge.a > 0.5, "trailing edge should still be covered by the layer, not a transparent gap")
        #expect(trailingEdge.r > 0.5 && trailingEdge.b < 0.5, "trailing edge should be the red layer's color")
    }

    /// Sanity check at rest (contentOffset: 0): with no travel at all, the whole frame should be
    /// solid red, no gaps anywhere -- isolates "does the layer render and cover the frame at
    /// all" from "does it survive being moved."
    @Test
    func atRestFullyCoversFrame() throws {
        let width = 200.0
        let height = 20.0
        let base = Color.clear.frame(width: width, height: height)
        let full = try layers(factor: 1)

        let buffer = try #require(renderPixels(
            base.thomasParallaxBackgrounds(full, axis: .horizontal, contentOffset: 0, maxTravel: 100),
            size: CGSize(width: width, height: height)
        ))

        for x in [0, 50, 100, 150, 199] {
            let p = pixel(buffer, width: Int(width), x: x, y: Int(height) / 2)
            #expect(p.a > 0.5, "x=\(x) should be covered by the layer at rest")
        }
    }

    /// A negative factor moves the layer toward the end, so its slack must sit on the leading
    /// edge: the frame stays covered at rest and at full travel.
    @Test
    func negativeFactorCoversFrameAtRestAndFullTravel() throws {
        let width = 200.0
        let height = 20.0
        let maxTravel = 400.0
        let base = Color.clear.frame(width: width, height: height)
        let reversed = try layers(factor: -0.5)

        for contentOffset in [0, -maxTravel / 2, -maxTravel] {
            let buffer = try #require(renderPixels(
                base.thomasParallaxBackgrounds(reversed, axis: .horizontal, contentOffset: contentOffset, maxTravel: maxTravel),
                size: CGSize(width: width, height: height)
            ))
            for x in [0, Int(width) / 2, Int(width) - 1] {
                let p = pixel(buffer, width: Int(width), x: x, y: Int(height) / 2)
                #expect(p.a > 0.5, "x=\(x) should be covered at contentOffset \(contentOffset)")
            }
        }
    }

    /// Overscroll past either end holds the layer at its limit instead of exposing its edge.
    @Test
    func overscrollNeverRevealsGap() throws {
        let width = 200.0
        let height = 20.0
        let maxTravel = 100.0
        let base = Color.clear.frame(width: width, height: height)
        let full = try layers(factor: 1)

        for contentOffset in [40, -(maxTravel + 40)] {
            let buffer = try #require(renderPixels(
                base.thomasParallaxBackgrounds(full, axis: .horizontal, contentOffset: contentOffset, maxTravel: maxTravel),
                size: CGSize(width: width, height: height)
            ))
            for x in [0, Int(width) - 1] {
                let p = pixel(buffer, width: Int(width), x: x, y: Int(height) / 2)
                #expect(p.a > 0.5, "x=\(x) should be covered at contentOffset \(contentOffset)")
            }
        }
    }

    /// The tracker-driven overload renders exactly what the value-driven one does for the same
    /// offset.
    @Test
    func trackedOffsetRendersLikeValueOffset() throws {
        let width = 300.0
        let height = 20.0
        let base = Color.clear.frame(width: width, height: height)
        let layers = try stepLayers(factor: 0.5)
        let tracker = ThomasContentOffsetTracker()
        tracker.offset = -60

        let tracked = try #require(renderPixels(
            base.thomasParallaxBackgrounds(layers, axis: .horizontal, offsetTracker: tracker, maxTravel: 100),
            size: CGSize(width: width, height: height)
        ))
        let value = try #require(renderPixels(
            base.thomasParallaxBackgrounds(layers, axis: .horizontal, contentOffset: -60, maxTravel: 100),
            size: CGSize(width: width, height: height)
        ))
        let atRest = try #require(renderPixels(
            base.thomasParallaxBackgrounds(layers, axis: .horizontal, contentOffset: 0, maxTravel: 100),
            size: CGSize(width: width, height: height)
        ))

        #expect(tracked == value)
        #expect(tracked != atRest, "the step layer must visibly move, or the comparison above proves nothing")
    }

    /// `thomasTrackContentOffset` reports the content moving opposite the scroll.
    @Test
    func trackerFollowsVerticalScroll() async throws {
        let tracker = ThomasContentOffsetTracker()
        let (window, scrollView) = try hostScroll(.vertical, tracker: tracker, direction: .leftToRight)
        defer { window.isHidden = true }
        let restOffset = tracker.offset
        scrollView.setContentOffset(CGPoint(x: 0, y: scrollView.contentOffset.y + 120), animated: false)

        try await waitFor { abs(tracker.offset - (restOffset - 120)) <= 1 }
        #expect(abs(tracker.offset - (restOffset - 120)) <= 1)
    }

    /// A horizontal scroll reads 0 at rest and goes negative scrolling forward in both layout
    /// directions, though a right-to-left scroll rests at its physical end.
    @Test(arguments: [LayoutDirection.leftToRight, .rightToLeft])
    func trackerMeasuresHorizontalScrollFromLeadingEdge(direction: LayoutDirection) async throws {
        let tracker = ThomasContentOffsetTracker()
        let (window, scrollView) = try hostScroll(.horizontal, tracker: tracker, direction: direction)
        defer { window.isHidden = true }
        try await waitFor { abs(tracker.offset) <= 1 }
        #expect(abs(tracker.offset) <= 1)

        let forward: CGFloat = direction == .rightToLeft ? -120 : 120
        scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x + forward, y: 0), animated: false)

        try await waitFor { abs(tracker.offset + 120) <= 1 }
        #expect(abs(tracker.offset + 120) <= 1)
    }

    /// Hosts a 1000pt-long tracked scroll in a 300pt window; the caller keeps the window alive.
    private func hostScroll(
        _ axis: Axis,
        tracker: ThomasContentOffsetTracker,
        direction: LayoutDirection
    ) throws -> (UIWindow, UIScrollView) {
        let spaceName = "test.parallax.scroll"
        let viewport: CGFloat = 300
        let host = UIHostingController(rootView:
            ScrollView(axis == .vertical ? .vertical : .horizontal) {
                Color.red
                    .frame(width: axis == .vertical ? 100 : 1000, height: axis == .vertical ? 1000 : 100)
                    .thomasTrackContentOffset(
                        tracker,
                        axis: axis,
                        coordinateSpaceName: spaceName,
                        viewportLength: viewport
                    )
            }
            .coordinateSpace(name: spaceName)
            .environment(\.layoutDirection, direction)
        )
        let window = UIWindow(frame: CGRect(
            x: 0, y: 0,
            width: axis == .vertical ? 100 : viewport,
            height: axis == .vertical ? viewport : 100
        ))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        return (window, try #require(Self.firstScrollView(in: host.view)))
    }

    private func waitFor(_ condition: () -> Bool) async throws {
        for _ in 0..<50 where !condition() {
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    private static func firstScrollView(in view: UIView) -> UIScrollView? {
        if let scrollView = view as? UIScrollView { return scrollView }
        for subview in view.subviews {
            if let found = firstScrollView(in: subview) { return found }
        }
        return nil
    }

    /// The actual displacement: a sharp-edged gradient layer's visible edge should land at
    /// exactly `factor * contentOffset` points away from where it sits at rest.
    @Test
    func edgeMovesByExactlyFactorTimesContentOffset() throws {
        let width = 300.0
        let height = 20.0
        let maxTravel = 100.0
        let factor = 1.0
        let base = Color.clear.frame(width: width, height: height)
        let stepLayers = try stepLayers(factor: factor)

        func edgeX(atOffset contentOffset: CGFloat) throws -> Int {
            let buffer = try #require(renderPixels(
                base.thomasParallaxBackgrounds(stepLayers, axis: .horizontal, contentOffset: contentOffset, maxTravel: maxTravel),
                size: CGSize(width: width, height: height)
            ))
            for x in 0..<(Int(width) - 1) {
                let here = pixel(buffer, width: Int(width), x: x, y: Int(height) / 2)
                let next = pixel(buffer, width: Int(width), x: x + 1, y: Int(height) / 2)
                if here.a > 0.5 && next.a > 0.5 && here.r > 0.5 && next.b > 0.5 {
                    return x
                }
            }
            Issue.record("No red-to-blue edge found")
            return -1
        }

        let restEdge = try edgeX(atOffset: 0)
        let movedEdge = try edgeX(atOffset: -60)

        // Allows 1px for the sampling scan's resolution.
        #expect(abs((restEdge - movedEdge) - 60) <= 1)
    }

    @Test
    func pagerTravelIsOneWidthPerPageAfterTheFirst() {
        #expect(Pager.parallaxTravel(pageWidth: 300, pageCount: 0) == 0)
        #expect(Pager.parallaxTravel(pageWidth: 300, pageCount: 1) == 0)
        #expect(Pager.parallaxTravel(pageWidth: 300, pageCount: 2) == 300)
        #expect(Pager.parallaxTravel(pageWidth: 300, pageCount: 4) == 900)
    }
}
