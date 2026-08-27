/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Testing

@testable @_spi(AirshipInternal) import AirshipSceneRenderer

/// A placement's declared size is the whole footprint and its border is drawn within it, so the
/// content is sized to that size less the stroke on both edges and the border modifier's padding
/// brings the footprint back to what the author asked for.
///
/// iOS used to add the placement border *outside* the declared size, leaving a bordered scene
/// `2 x stroke` larger than Android and web rendered the same definition.
@Suite("ViewConstraints border box")
struct ViewConstraintsBorderBoxTest {

    /// 400 x 800, no insets, so a percentage is easy to read off.
    private let window = ViewConstraints(
        size: CGSize(width: 400, height: 800),
        safeAreaInsets: EdgeInsets()
    )

    private func size(
        width: ThomasSizeConstraint = .auto,
        height: ThomasSizeConstraint = .auto,
        minWidth: ThomasSizeConstraint? = nil,
        maxWidth: ThomasSizeConstraint? = nil,
        minHeight: ThomasSizeConstraint? = nil,
        maxHeight: ThomasSizeConstraint? = nil,
        aspectRatio: Double? = nil
    ) -> ThomasConstrainedSize {
        ThomasConstrainedSize(
            minWidth: minWidth,
            width: width,
            maxWidth: maxWidth,
            minHeight: minHeight,
            height: height,
            maxHeight: maxHeight,
            aspectRatio: aspectRatio
        )
    }

    @Test("a declared length is the footprint, so the content comes back a stroke smaller")
    func declaredLengthIsFootprint() {
        let result = window.contentConstraints(
            size(width: .percent(60), height: .percent(50)),
            contentSize: nil,
            margin: nil,
            borderStrokeWidth: 40
        )

        #expect(result.width == 160, "width \(String(describing: result.width))")   // 60% of 400, less 2 x 40
        #expect(result.height == 320, "height \(String(describing: result.height))")  // 50% of 800, less 2 x 40
    }

    @Test("no border leaves the declared length exactly as declared")
    func noBorderIsUnchanged() {
        let result = window.contentConstraints(
            size(width: .percent(60), height: .percent(50)),
            contentSize: nil,
            margin: nil
        )

        #expect(result.width == 240)
        #expect(result.height == 400)
    }

    @Test("a floor is a bound like any other and comes down with the rest")
    func minimumIsDeducted() {
        let result = window.contentConstraints(
            size(minWidth: .percent(50), minHeight: .percent(50)),
            contentSize: nil,
            margin: nil,
            borderStrokeWidth: 40
        )

        // Auto on both axes, so the floors travel as floors rather than becoming lengths.
        #expect(result.width == nil)
        #expect(result.height == nil)
        #expect(result.minWidth == 120, "minWidth \(String(describing: result.minWidth))")
        #expect(result.minHeight == 320, "minHeight \(String(describing: result.minHeight))")
    }

    @Test("an auto axis has no footprint to fit a border inside, so nothing is taken out")
    func autoAxisIsUntouched() {
        let result = window.contentConstraints(
            size(),
            contentSize: nil,
            margin: nil,
            borderStrokeWidth: 40
        )

        #expect(result.width == nil)
        #expect(result.height == nil)
    }

    @Test("a stroke wider than the length it sits in clamps at zero rather than going negative")
    func strokeWiderThanLength() {
        let result = window.contentConstraints(
            size(width: .points(10), height: .points(10)),
            contentSize: nil,
            margin: nil,
            borderStrokeWidth: 40
        )

        #expect(result.width == 0)
        #expect(result.height == 0)
    }

    /// The bound is compared against a measurement and then handed back as a length, so the two
    /// have to name the same number. When they don't, the clamp lets go, the content grows back to
    /// its natural height, exceeds the bound and clamps again — every pass, forever.
    @Test("a maximum that has clamped stays clamped once the content measures at it")
    func maximumReachesAFixedPoint() throws {
        let declared = size(width: .percent(60), height: .auto, maxHeight: .percent(50))

        // Nothing measured yet: auto, so no length.
        let first = window.contentConstraints(
            declared, contentSize: nil, margin: nil, borderStrokeWidth: 40
        )
        #expect(first.height == nil)

        // Content overruns the cap, so the cap becomes the length.
        let overrun = CGSize(width: first.width ?? 0, height: 10_000)
        let second = window.contentConstraints(
            declared, contentSize: overrun, margin: nil, borderStrokeWidth: 40
        )
        let clamped = try #require(second.height)
        #expect(clamped == 320, "clamped \(clamped), first.width \(String(describing: first.width))")

        // Content now measures at exactly the clamp. It must hold, not release.
        let settled = CGSize(width: second.width ?? 0, height: clamped)
        let third = window.contentConstraints(
            declared, contentSize: settled, margin: nil, borderStrokeWidth: 40
        )
        #expect(third.height == clamped)
    }

    /// The same walk with numbers that don't land on whole points, which is where a comparison
    /// against an unrounded bound would come apart.
    @Test("a fractional stroke against a fractional percentage still settles")
    func fractionalStrokeSettles() {
        let window = ViewConstraints(
            size: CGSize(width: 402, height: 874),
            safeAreaInsets: EdgeInsets()
        )
        let declared = size(width: .percent(60), height: .auto, maxHeight: .percent(50))

        var measured: CGSize? = CGSize(width: 0, height: 10_000)
        var heights: [CGFloat?] = []

        for _ in 0..<6 {
            let result = window.contentConstraints(
                declared, contentSize: measured, margin: nil, borderStrokeWidth: 2.5
            )
            heights.append(result.height)
            measured = CGSize(
                width: result.width ?? 0,
                height: result.height ?? 10_000
            )
        }

        // Pinned to the value rather than merely to each other: every pass agreeing on the
        // *undeducted* 437 would satisfy "they are all equal" while the stroke went missing.
        // 50% of 874 is 437, less 2 x 2.5.
        #expect(heights.allSatisfy { $0 == 432 }, "heights \(heights)")
    }

    @Test("adding the border back returns the footprint the author declared")
    func addingBorderIsTheInverse() {
        let content = window.contentConstraints(
            size(width: .percent(60), height: .percent(50)),
            contentSize: nil,
            margin: nil,
            borderStrokeWidth: 40
        )

        let footprint = content.addingBorder(40)
        #expect(footprint.width == 240)
        #expect(footprint.height == 400)
    }

    /// The deduction takes the stroke out of the bounds as well as the lengths, so the trip back has
    /// to restore them too — otherwise what comes back carries a footprint length beside
    /// content-space bounds, and nothing in the type says which is which.
    @Test("adding the border back restores the bounds, not only the lengths")
    func addingBorderRestoresBounds() {
        let content = window.contentConstraints(
            size(
                width: .percent(60),
                height: .auto,
                minHeight: .percent(25),
                maxHeight: .percent(50)
            ),
            contentSize: nil,
            margin: nil,
            borderStrokeWidth: 40
        )

        // 25% and 50% of 800, each less 2 x 40 on the way in.
        #expect(content.minHeight == 120, "minHeight \(String(describing: content.minHeight))")
        #expect(content.maxHeight == 320, "maxHeight \(String(describing: content.maxHeight))")

        let footprint = content.addingBorder(40)
        #expect(footprint.minHeight == 200, "minHeight \(String(describing: footprint.minHeight))")
        #expect(footprint.maxHeight == 400, "maxHeight \(String(describing: footprint.maxHeight))")
    }

    /// A banner measures itself outside its border modifier, so what it caches is the footprint
    /// rather than the content box a modal caches. `BannerView` converts on the way in and back on
    /// the way out; both conversions have to land on the declared size, not a stroke either side.
    @Test("a banner measured at its footprint settles at the declared maximum")
    func bannerFootprintMeasurementSettles() {
        let declared = size(width: .percent(60), height: .auto, maxHeight: .percent(50))
        let strokeWidth = 40.0

        var measuredFootprint: CGSize? = CGSize(width: 0, height: 10_000)
        var footprints: [CGFloat?] = []

        for _ in 0..<6 {
            // The same conversion `BannerView` applies, rather than a copy of it here — a copy
            // would keep passing if the two directions drifted apart in the view.
            let asContent = measuredFootprint.map { measured in
                ViewConstraints.deductingBorder(from: measured, strokeWidth: strokeWidth)
            }
            let result = window.contentConstraints(
                declared, contentSize: asContent, margin: nil, borderStrokeWidth: strokeWidth
            )
            let rendered = result.addingBorder(strokeWidth)
            footprints.append(rendered.height)
            measuredFootprint = CGSize(
                width: rendered.width ?? 0,
                height: rendered.height ?? 10_000
            )
        }

        // 50% of 800, as declared — the border is inside it rather than added on top.
        #expect(footprints.allSatisfy { $0 == 400 })
    }

    @Test("the parity scene lands where Android and web put it")
    func matchesTheOtherPlatforms() {
        // iPhone 17 Pro, safe area 778pt tall. `_border-box-parity.yml` declares 60% x 50% with a
        // 40pt stroke; Android and web both render the footprint at the declared size.
        let window = ViewConstraints(
            size: CGSize(width: 402, height: 778),
            safeAreaInsets: EdgeInsets()
        )

        let result = window.contentConstraints(
            size(width: .percent(60), height: .percent(50)),
            contentSize: nil,
            margin: nil,
            borderStrokeWidth: 40
        )

        // Footprint 241 x 389 once the border modifier adds the stroke back on.
        #expect(result.width == 161)
        #expect(result.height == 309)
    }
}