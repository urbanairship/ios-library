/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Testing

@testable @_spi(AirshipInternal) import AirshipSceneRenderer

/// A placement that declares one length and an aspect ratio derives the other length from it, and
/// when that box overflows the space available it shrinks to the largest box of the ratio that fits.
@Suite("ViewConstraints aspect fit")
struct ViewConstraintsAspectFitTest {

    private let tall = ViewConstraints(
        size: CGSize(width: 400, height: 800),
        safeAreaInsets: EdgeInsets()
    )

    private let wide = ViewConstraints(
        size: CGSize(width: 800, height: 400),
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

    @Test("a full height square in a tall window fits to the window's width")
    func heightDeclaredOverflowsWidth() {
        let result = tall.contentConstraints(
            size(height: .percent(100), aspectRatio: 1),
            contentSize: nil,
            margin: nil
        )

        #expect(result.width == 400)
        #expect(result.height == 400)
        #expect(result.aspectRatio == 1)
    }

    @Test("a full width square in a wide window fits to the window's height")
    func widthDeclaredOverflowsHeight() {
        let result = wide.contentConstraints(
            size(width: .percent(100), aspectRatio: 1),
            contentSize: nil,
            margin: nil
        )

        #expect(result.width == 400)
        #expect(result.height == 400)
        #expect(result.aspectRatio == 1)
    }

    @Test("a box that fits keeps its declared length")
    func fitsIsUnchanged() {
        let result = tall.contentConstraints(
            size(width: .percent(100), aspectRatio: 1),
            contentSize: nil,
            margin: nil
        )

        #expect(result.width == 400)
        #expect(result.height == 400)

        let half = tall.contentConstraints(
            size(height: .percent(25), aspectRatio: 1),
            contentSize: nil,
            margin: nil
        )

        #expect(half.width == 200)
        #expect(half.height == 200)
    }

    @Test("content measured at the ceiling of the derived axis keeps the fit")
    func measuredContentKeepsFit() {
        let declared = size(height: .percent(100), aspectRatio: 1)
        let first = tall.contentConstraints(declared, contentSize: nil, margin: nil)
        let second = tall.contentConstraints(
            declared,
            contentSize: CGSize(width: first.width ?? 0, height: first.height ?? 0),
            margin: nil
        )

        #expect(second.width == 400)
        #expect(second.height == 400)
        #expect(second.aspectRatio == 1)
    }

    @Test("a declared maximum bounds the fit like the window does")
    func maximumBoundsTheFit() {
        let result = tall.contentConstraints(
            size(height: .percent(100), maxWidth: .points(300), aspectRatio: 1),
            contentSize: nil,
            margin: nil
        )

        #expect(result.width == 300)
        #expect(result.height == 300)
    }

    @Test("a declared minimum holds against the fit")
    func minimumHoldsAgainstTheFit() {
        let result = tall.contentConstraints(
            size(height: .percent(100), minHeight: .percent(75), aspectRatio: 1),
            contentSize: nil,
            margin: nil
        )

        #expect(result.width == 400)
        #expect(result.height == 600)
    }

    @Test("the fitted footprint is square with the border inside it")
    func strokeIsInsideTheFit() {
        let result = tall.contentConstraints(
            size(height: .percent(100), aspectRatio: 1),
            contentSize: nil,
            margin: nil,
            borderStrokeWidth: 10
        )

        // Footprint 400 x 400 once the border modifier adds 2 x 10 back on each axis.
        #expect(result.width == 380)
        #expect(result.height == 380)
    }

    @Test("margins come out of the space the box fits within")
    func marginsShrinkTheFit() {
        let result = tall.contentConstraints(
            size(height: .percent(100), aspectRatio: 1),
            contentSize: nil,
            margin: ThomasMargin(top: 0, bottom: 0, start: 20, end: 20)
        )

        #expect(result.width == 360)
        #expect(result.height == 360)
    }
}
