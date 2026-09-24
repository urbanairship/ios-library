/* Copyright Airship and Contributors */

import CoreGraphics
import SwiftUI
import Testing

@testable import AirshipSceneRenderer

/// Covers `Gradient.linearGradientPoints`'s hard case: any non-axis-aligned angle, where CSS's
/// corner-to-corner gradient line length is a real pixel measurement, not a unit vector. A
/// naive unit vector only agrees with the correct answer at the four axis-aligned angles, which
/// is why a bug here can hide behind axis-aligned test cases alone.
struct ThomasBackgroundGradientTest {

    private typealias Gradient = ThomasBackground.GradientBackground.Gradient

    private func expect(
        _ actual: (start: UnitPoint, end: UnitPoint),
        start: UnitPoint,
        end: UnitPoint,
        accuracy: Double = 1e-9
    ) {
        #expect(abs(actual.start.x - start.x) < accuracy)
        #expect(abs(actual.start.y - start.y) < accuracy)
        #expect(abs(actual.end.x - end.x) < accuracy)
        #expect(abs(actual.end.y - end.y) < accuracy)
    }

    /// The general aspect-ratio-dependent case: a naive unit vector would offset each axis by
    /// the same fraction, but the correct CSS corner-to-corner length offsets each axis by a
    /// different fraction on a non-square box.
    @Test
    func fortyFiveDegreesOnNonSquareBox() {
        let points = Gradient.linearGradientPoints(angle: 45, size: CGSize(width: 200, height: 100))

        expect(
            points,
            start: UnitPoint(x: 0.125, y: 1.25),
            end: UnitPoint(x: 0.875, y: -0.25)
        )
    }

    /// Same magnitudes as 45°, mirrored in y, since
    /// `cos(135°) = -cos(45°)` flips the sign of `dy` while `sin(135°) = sin(45°)` leaves `dx`
    /// alone.
    @Test
    func oneThirtyFiveDegreesOnNonSquareBox() {
        let points = Gradient.linearGradientPoints(angle: 135, size: CGSize(width: 200, height: 100))

        expect(
            points,
            start: UnitPoint(x: 0.125, y: -0.25),
            end: UnitPoint(x: 0.875, y: 1.25)
        )
    }

    /// The four axis-aligned angles reduce to plain width or height, so they come out identical
    /// on a non-square box whether or not the aspect ratio is accounted for.
    @Test
    func axisAlignedAnglesUnaffectedByAspectRatio() {
        let size = CGSize(width: 200, height: 100)

        expect(
            Gradient.linearGradientPoints(angle: 0, size: size),
            start: UnitPoint(x: 0.5, y: 1),
            end: UnitPoint(x: 0.5, y: 0)
        )
        expect(
            Gradient.linearGradientPoints(angle: 90, size: size),
            start: UnitPoint(x: 0, y: 0.5),
            end: UnitPoint(x: 1, y: 0.5)
        )
        expect(
            Gradient.linearGradientPoints(angle: 180, size: size),
            start: UnitPoint(x: 0.5, y: 0),
            end: UnitPoint(x: 0.5, y: 1)
        )
        expect(
            Gradient.linearGradientPoints(angle: 270, size: size),
            start: UnitPoint(x: 1, y: 0.5),
            end: UnitPoint(x: 0, y: 0.5)
        )
    }

    /// No angle stated defaults to CSS's own default, "to bottom" (180°).
    @Test
    func noAngleDefaultsToTopToBottom() {
        let size = CGSize(width: 200, height: 100)

        expect(
            Gradient.linearGradientPoints(angle: nil, size: size),
            start: UnitPoint(x: 0.5, y: 0),
            end: UnitPoint(x: 0.5, y: 1)
        )
    }

    /// Even a square box needs the real pixel math, not a naive unit vector: at 45° the line
    /// runs exactly corner to corner, where a magnitude-1 unit vector falls short. The
    /// aspect-ratio cases above are the general form of this same case -- a square just makes
    /// "corner to corner" easy to verify by eye.
    @Test
    func fortyFiveDegreesOnSquareBoxReachesOppositeCorners() {
        let points = Gradient.linearGradientPoints(angle: 45, size: CGSize(width: 100, height: 100))

        expect(
            points,
            start: UnitPoint(x: 0, y: 1),
            end: UnitPoint(x: 1, y: 0)
        )
    }
}
