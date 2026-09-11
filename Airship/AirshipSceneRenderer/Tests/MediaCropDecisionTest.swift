/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Testing

@testable @_spi(AirshipInternal) import AirshipSceneRenderer

/// `shouldShowMediaWhole` decides whether `fit_crop`/`center_crop`/`center` media should be shown
/// at its own proportions or cropped to fill. Each case here pins down one shape of
/// `ViewConstraints` that decided a real bug, on either side of the fix in this file: a regression
/// test for `Container.flooringMeasuredShare`'s pinned share (the fix), and one for each of the two
/// ways trusting the wrong maximum went wrong before it (an ambient auto-axis ceiling, and an
/// ordinary sibling-derived one).
@Suite("Media crop decision")
struct MediaCropDecisionTest {

    private func constraints(
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        maxWidth: CGFloat? = nil,
        maxHeight: CGFloat? = nil,
        minWidth: CGFloat? = nil,
        minHeight: CGFloat? = nil,
        measuredAxes: Axis.Set = [],
        pinnedAxes: Axis.Set = []
    ) -> ViewConstraints {
        ViewConstraints(
            width: width,
            height: height,
            maxWidth: maxWidth,
            maxHeight: maxHeight,
            minWidth: minWidth,
            minHeight: minHeight,
            measuredAxes: measuredAxes,
            pinnedAxes: pinnedAxes
        )
    }

    @Test("both axes declared is always a box, whatever the aspect ratio")
    func bothDeclaredCrops() {
        let result = shouldShowMediaWhole(
            constraints: constraints(width: 500, height: 100),
            aspectRatio: 1
        )
        #expect(result == false)
    }

    @Test("a declared width and a genuinely auto height shows the media whole when it already fits")
    func autoAxisThatFitsShowsWhole() {
        // 525 wide at a 1:1 ratio wants 525 tall, comfortably under a 1000 ceiling.
        let result = shouldShowMediaWhole(
            constraints: constraints(width: 525, maxHeight: 1000),
            aspectRatio: 1
        )
        #expect(result == true)
    }

    @Test("a declared width and a genuinely auto height crops against a real, authored ceiling")
    func autoAxisAgainstARealCeilingCrops() {
        // 525 wide at a 1:1 ratio wants 525 tall, which overruns a 200pt ceiling the author wrote.
        let result = shouldShowMediaWhole(
            constraints: constraints(width: 525, maxHeight: 200),
            aspectRatio: 1
        )
        #expect(result == false)
    }

    @Test(
        "an un-measured maximum is the room a view was given, not a length it has, so it isn't read as a box"
    )
    func unmeasuredMaximumIsNotALength() {
        // Regression test: resolvedLength(on:) once fell back to a bare maxWidth on an axis that
        // was never measured at all — the ambient ceiling an auto axis is handed down, not a
        // length belonging to this view. That made every declared-height/auto-width media read as
        // a box and always crop, skipping the fits-check below entirely.
        #expect(
            constraints(height: 80, maxWidth: 900).resolvedLength(on: .horizontal) == nil
        )

        let result = shouldShowMediaWhole(
            constraints: constraints(height: 80, maxWidth: 900),
            aspectRatio: 900.0 / 600.0
        )
        #expect(result == true, "80 tall at that ratio wants 120 wide, well under the 900 ceiling")
    }

    @Test(
        "a measured maximum with no matching floor is a sibling's extent, not a box to crop into"
    )
    func measuredWithoutAFloorIsNotTrusted() {
        // The original guard this protects: a fit_crop photo beside a two-character label. The
        // label leaves the photo a small measured maxWidth with nothing floored under it, so
        // cropping into that number would show a strip of the photo rather than the photo itself.
        let result = shouldShowMediaWhole(
            constraints: constraints(height: 80, maxWidth: 40, measuredAxes: .horizontal),
            aspectRatio: 900.0 / 600.0
        )
        #expect(result == true)
    }

    @Test("a measured maximum pinned by an equal floor is a real length, and media crops into it")
    func measuredAndPinnedIsTrusted() {
        // The bug this PR fixes: Container.flooringMeasuredShare turns a 100% share of a measured
        // container into (length: nil, floor: share) rather than a length, so a background image
        // declared height: 100% landed here. Before the fix this read as "no box" and showed the
        // image at its own proportions instead of filling the frame.
        let pinned = constraints(
            width: 525,
            maxHeight: 396.5,
            minHeight: 396.5,
            measuredAxes: .vertical,
            pinnedAxes: .vertical
        )

        #expect(pinned.resolvedLength(on: .vertical) == 396.5)
        #expect(pinned.limit(on: .vertical) == 396.5)

        // 642x350 source: scaling to width 525 alone would only reach ~286 tall, comfortably under
        // 396.5 — the old "does it already fit" check would have shown it whole. Pinned, the axis
        // is a box regardless, so it crops.
        let result = shouldShowMediaWhole(constraints: pinned, aspectRatio: 642.0 / 350.0)
        #expect(result == false)
    }

    @Test("neither axis given falls back to whole only where no maximum, measured or not, limits either one")
    func neitherDeclaredFallsBackToMaximumCheck() {
        #expect(shouldShowMediaWhole(constraints: constraints(), aspectRatio: 1) == true)
        #expect(
            shouldShowMediaWhole(
                constraints: constraints(maxWidth: 100, maxHeight: 100),
                aspectRatio: 1
            ) == false
        )
    }
}
