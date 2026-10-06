/* Copyright Airship and Contributors */

#if !os(macOS) && !os(watchOS)

import SwiftUI
import Testing

@testable import AirshipSceneRenderer

/// Samples rendered `thomasBackgrounds` gradients to check they blend the way CSS does.
@MainActor
struct BackgroundGradientRenderingTest {

    private func gradientLayers(from start: String, to end: String) throws -> [ThomasBackground] {
        try JSONDecoder().decode([ThomasBackground].self, from: Data("""
            [{
                "type": "gradient",
                "gradient": { "style": "linear", "angle": 90, "stops": [
                    { "color": { "default": \(start) }, "position": 0 },
                    { "color": { "default": \(end) }, "position": 1 }
                ]}
            }]
            """.utf8))
    }

    @Test
    func interpolatesInSRGBSpace() throws {
        let width = 200
        let height = 10
        let layers = try gradientLayers(
            from: ##"{ "hex": "#000000", "alpha": 1 }"##,
            to: ##"{ "hex": "#FFFFFF", "alpha": 1 }"##
        )

        let view = Color.clear
            .frame(width: CGFloat(width), height: CGFloat(height))
            .thomasBackgrounds(layers)

        let buffer = try #require(renderPixels(view, size: CGSize(width: CGFloat(width), height: CGFloat(height))))
        let midpoint = pixel(buffer, width: width, x: width / 2, y: height / 2)

        #expect(abs(midpoint.r - 0.5) < 0.05)
    }

    /// A fade to transparent keeps its hue midway, as CSS's premultiplied blend does, rather
    /// than dimming toward the transparent stop's black.
    @Test
    func fadeToTransparentDoesNotDarken() throws {
        let width = 200
        let height = 10
        let layers = try gradientLayers(
            from: ##"{ "hex": "#FF0000", "alpha": 1 }"##,
            to: ##"{ "hex": "#000000", "alpha": 0 }"##
        )

        let view = ZStack {
            Color.white
            Color.clear
                .frame(width: CGFloat(width), height: CGFloat(height))
                .thomasBackgrounds(layers)
        }

        let buffer = try #require(renderPixels(view, size: CGSize(width: CGFloat(width), height: CGFloat(height))))
        let midpoint = pixel(buffer, width: width, x: width / 2, y: height / 2)

        #expect(midpoint.r > 0.9)
        #expect(abs(midpoint.g - 0.5) < 0.1)
    }

    /// Angles are physical, as in CSS: a 90° gradient still runs left to right under RTL.
    @Test
    func angleIsNotMirroredRightToLeft() throws {
        let width = 200
        let height = 10
        let layers = try gradientLayers(
            from: ##"{ "hex": "#FF0000", "alpha": 1 }"##,
            to: ##"{ "hex": "#0000FF", "alpha": 1 }"##
        )

        let view = Color.clear
            .frame(width: CGFloat(width), height: CGFloat(height))
            .thomasBackgrounds(layers)
            .environment(\.layoutDirection, .rightToLeft)

        let buffer = try #require(renderPixels(view, size: CGSize(width: CGFloat(width), height: CGFloat(height))))
        let left = pixel(buffer, width: width, x: 1, y: height / 2)
        let right = pixel(buffer, width: width, x: width - 2, y: height / 2)

        #expect(left.r > 0.8 && left.b < 0.2)
        #expect(right.b > 0.8 && right.r < 0.2)
    }
}

#endif
