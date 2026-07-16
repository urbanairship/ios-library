/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Testing

@testable import AirshipBasement
@testable @_spi(AirshipInternal) import AirshipSceneRenderer

@Suite(.timeLimit(.minutes(1)))
struct BannerSwipeDismissLogicTest {

    /// A banner position/layout-direction pairing, with the sign of a drag
    /// offset that moves the banner toward its dismiss edge.
    private struct Anchor {
        let name: String
        let position: ThomasEdgePosition
        let layoutDirection: LayoutDirection
        let dismissSign: CGFloat
    }

    private static func anchors() throws -> [Anchor] {
        let top = try ThomasEdgePosition(horizontal: .center, vertical: .top)
        let bottom = try ThomasEdgePosition(horizontal: .center, vertical: .bottom)
        let centerStart = try ThomasEdgePosition(horizontal: .start, vertical: .center)
        let centerEnd = try ThomasEdgePosition(horizontal: .end, vertical: .center)

        return [
            Anchor(name: "top LTR", position: top, layoutDirection: .leftToRight, dismissSign: -1),
            Anchor(name: "top RTL", position: top, layoutDirection: .rightToLeft, dismissSign: -1),
            Anchor(name: "bottom LTR", position: bottom, layoutDirection: .leftToRight, dismissSign: 1),
            Anchor(name: "bottom RTL", position: bottom, layoutDirection: .rightToLeft, dismissSign: 1),
            Anchor(name: "center-start LTR", position: centerStart, layoutDirection: .leftToRight, dismissSign: -1),
            Anchor(name: "center-start RTL", position: centerStart, layoutDirection: .rightToLeft, dismissSign: 1),
            Anchor(name: "center-end LTR", position: centerEnd, layoutDirection: .leftToRight, dismissSign: 1),
            Anchor(name: "center-end RTL", position: centerEnd, layoutDirection: .rightToLeft, dismissSign: -1)
        ]
    }

    @Test
    func swipeDismissDecision() throws {
        // Offsets are expressed as multiples of the dismiss-direction sign; a
        // negative multiple drags away from the dismiss edge. The extent is
        // 100, so the idle threshold (40%) is 40pt and the fling threshold
        // (10%) is 10pt. A predicted end offset equal to the offset is an
        // idle release; one continuing past it is a fling.
        let cases: [(name: String, offset: CGFloat, predicted: CGFloat, extent: CGFloat?, expected: Bool)] = [
            ("idle below threshold (39%)", 39, 39, 100, false),
            ("idle above threshold (41%)", 41, 41, 100, true),
            ("fling toward dismiss edge above fling threshold", 15, 115, 100, true),
            ("fling toward dismiss edge at/below fling threshold", 10, 110, 100, false),
            ("fling away from dismiss edge", 15, -50, 100, false),
            ("drag away from dismiss edge", -41, -41, 100, false),
            ("nil extent: fallback distance exceeded", 101, 101, nil, true),
            ("nil extent: below fallback distance, no fling", 99, 99, nil, false),
            ("nil extent: fling toward dismiss edge", 30, 130, nil, true),
            ("nil extent: fling away from dismiss edge", 30, -50, nil, false),
            ("nil extent: drag away from dismiss edge", -101, -101, nil, false),
            ("zero extent: fallback distance exceeded", 101, 101, 0, true),
            ("zero extent: below fallback distance, no fling", 99, 99, 0, false)
        ]

        for anchor in try Self.anchors() {
            for testCase in cases {
                let result = BannerView.shouldDismissOnSwipe(
                    offset: testCase.offset * anchor.dismissSign,
                    predictedEndOffset: testCase.predicted * anchor.dismissSign,
                    extent: testCase.extent,
                    position: anchor.position,
                    layoutDirection: anchor.layoutDirection
                )
                #expect(
                    result == testCase.expected,
                    "\(anchor.name): \(testCase.name)"
                )
            }
        }
    }

    @Test
    func isTowardDismissEdge() throws {
        for anchor in try Self.anchors() {
            #expect(
                BannerView.isTowardDismissEdge(
                    10 * anchor.dismissSign,
                    position: anchor.position,
                    layoutDirection: anchor.layoutDirection
                ),
                "\(anchor.name): toward dismiss edge"
            )
            #expect(
                !BannerView.isTowardDismissEdge(
                    -10 * anchor.dismissSign,
                    position: anchor.position,
                    layoutDirection: anchor.layoutDirection
                ),
                "\(anchor.name): away from dismiss edge"
            )
            #expect(
                !BannerView.isTowardDismissEdge(
                    0,
                    position: anchor.position,
                    layoutDirection: anchor.layoutDirection
                ),
                "\(anchor.name): no movement"
            )
        }
    }

    @Test
    func bannerSlideEdgeSelection() throws {
        // Corners use the vertical edge; vertically-centered banners use
        // their horizontal edge.
        let cases: [(ThomasPosition.Horizontal, ThomasPosition.Vertical, Edge)] = [
            (.start, .top, .top),
            (.center, .top, .top),
            (.end, .top, .top),
            (.start, .bottom, .bottom),
            (.center, .bottom, .bottom),
            (.end, .bottom, .bottom),
            (.start, .center, .leading),
            (.end, .center, .trailing)
        ]

        for (horizontal, vertical, expected) in cases {
            let position = try ThomasEdgePosition(horizontal: horizontal, vertical: vertical)
            #expect(
                position.bannerSlideEdge == expected,
                "\(horizontal.rawValue)-\(vertical.rawValue)"
            )
        }
    }
}
