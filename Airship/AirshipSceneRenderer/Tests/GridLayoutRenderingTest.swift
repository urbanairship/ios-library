/* Copyright Airship and Contributors */

#if !os(macOS) && !os(watchOS) && !os(tvOS)

import Foundation
import SwiftUI
import Testing
import UIKit

@_spi(AirshipInternal) import AirshipBasement
@testable @_spi(AirshipInternal) import AirshipSceneRenderer

/// Renders real grids in a window and reads box extents off the pixels, pinning the geometry web draws for the same payload.
@MainActor
@Suite("Grid layout rendering")
struct GridLayoutRenderingTest {

    private final class StubThomasDelegate: ThomasDelegate {
        func onVisibilityChanged(isVisible: Bool, isForegrounded: Bool) {}
        func onReportingEvent(_ event: ThomasReportingEvent) {}
        func onDismissed(cancel: Bool) {}
        func onStateChanged(_ state: AirshipJSON) {}
    }

    private let thomasEnvironment = ThomasEnvironment(delegate: StubThomasDelegate(), extensions: TestThomasExtensions())
    private let thomasState = ThomasState(onStateChange: { _ in })

    private static let size = CGSize(width: 400, height: 400)

    private struct Snapshot {
        let pixels: [UInt8]
        let width: Int
        let height: Int

        func isColor(_ x: Int, _ y: Int, _ color: (Int, Int, Int)) -> Bool {
            let offset = (y * width + x) * 4
            return abs(Int(pixels[offset]) - color.0) < 8
                && abs(Int(pixels[offset + 1]) - color.1) < 8
                && abs(Int(pixels[offset + 2]) - color.2) < 8
        }

        /// The runs of `color` down column `x`, as (start, length).
        func verticalRuns(x: Int, _ color: (Int, Int, Int)) -> [(Int, Int)] {
            runs((0..<height).map { isColor(x, $0, color) })
        }

        /// The runs of `color` along row `y`, as (start, length).
        func horizontalRuns(y: Int, _ color: (Int, Int, Int)) -> [(Int, Int)] {
            runs((0..<width).map { isColor($0, y, color) })
        }

        private func runs(_ flags: [Bool]) -> [(Int, Int)] {
            var result: [(Int, Int)] = []
            var start: Int?
            for (index, flag) in (flags + [false]).enumerated() {
                if flag, start == nil { start = index }
                if !flag, let begin = start {
                    result.append((begin, index - begin))
                    start = nil
                }
            }
            return result
        }
    }

    private static let red = (255, 0, 0)
    private static let blue = (0, 0, 255)
    private static let green = (0, 255, 0)

    private static func fill(_ hex: String) -> String {
        #"{"type": "empty_view", "background_color": {"default": {"type": "hex", "hex": "\#(hex)", "alpha": 1}}}"#
    }

    private static let longLabel = #"""
    {"type": "label", "text": "A much longer body that wraps across several lines inside its narrow grid cell for sure",
     "text_appearance": {"font_size": 14, "color": {"default": {"type": "hex", "hex": "#000000", "alpha": 1}}},
     "background_color": {"default": {"type": "hex", "hex": "#0000FF", "alpha": 1}}}
    """#

    /// Hosts `json` at the top-leading corner of a white window with `constraints`, and snapshots it once it settles.
    private func render(_ json: String, constraints: ViewConstraints) async throws -> Snapshot {
        let view = try JSONDecoder().decode(ThomasViewInfo.self, from: Data(json.utf8))
        let content = thomasEnvironment.viewFactory.createView(view, constraints: constraints)
            .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
            .background(Color.white)
            .environment(\.layoutDirection, .leftToRight)
            .environmentObject(thomasEnvironment)
            .environmentObject(thomasState)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        // Each render is one layout pass; the grid's measurements land on the main queue between them.
        for _ in 0..<6 {
            _ = renderer.cgImage
            try await Task.sleep(for: .milliseconds(30))
        }
        let cgImage = try #require(renderer.cgImage)
        let width = Int(Self.size.width)
        let height = Int(Self.size.height)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = try #require(CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(cgImage, in: CGRect(origin: .zero, size: Self.size))
        return Snapshot(pixels: pixels, width: width, height: height)
    }

    private func grid(width: String, items: [String], config: String = #"{"max_columns": 2}"#) -> String {
        #"""
        {"type": "linear_layout", "direction": "vertical", "items": [{
          "size": {"width": \#(width), "height": "auto"},
          "view": {
            "type": "grid_layout",
            "background_color": {"default": {"type": "hex", "hex": "#00FF00", "alpha": 1}},
            "config": {"default": \#(config)},
            "items": [\#(items.joined(separator: ","))]
          }
        }]}
        """#
    }

    private var bounded: ViewConstraints {
        ViewConstraints(width: Self.size.width, height: Self.size.height)
    }

    @Test("an unbounded grid with a minimum column width is a basis for a percentage beside it")
    func unboundedGridIsABasis() async throws {
        let json = #"""
        {"type": "linear_layout", "direction": "horizontal", "items": [
          {"size": {"width": "auto", "height": "auto"}, "view": {
            "type": "grid_layout",
            "config": {"default": {"max_columns": 3, "min_column_width": {"type": "fixed", "points": 40}, "column_spacing": 8}},
            "items": [
              {"size": {"width": "100%", "height": 20}, "view": \#(Self.fill("#FF0000"))},
              {"size": {"width": "100%", "height": 20}, "view": \#(Self.fill("#FF0000"))},
              {"size": {"width": "100%", "height": 20}, "view": \#(Self.fill("#FF0000"))}
            ]
          }},
          {"size": {"width": "50%", "height": 20}, "view": \#(Self.fill("#0000FF"))}
        ]}
        """#
        // What a horizontal scroll hands its content: no width, and the scrolling axis named.
        var content = ViewConstraints(height: 40)
        content.scrollingAxes = .horizontal
        let snapshot = try await render(json, constraints: content)

        // The grid is 3 × 40 + 2 × 8 = 136, so the stack solves to 136 / (1 − 0.5) and the box is half.
        let blue = try #require(snapshot.horizontalRuns(y: 20, Self.blue).first)
        #expect(blue.0 == 136)
        #expect(blue.1 == 136)
    }

    @Test("a percentage beside a fixed item is that share of the row")
    func shareOfFixedRow() async throws {
        let snapshot = try await render(grid(width: "300", items: [
            #"{"size": {"width": "100%", "height": 60}, "view": \#(Self.fill("#FF0000"))}"#,
            #"{"size": {"width": "100%", "height": "50%"}, "view": \#(Self.fill("#0000FF"))}"#,
        ]), constraints: bounded)

        // A 300pt grid centred in the 400pt stack spans 50...350, so its columns centre on 125 and 275.
        #expect(snapshot.verticalRuns(x: 125, Self.red).map(\.1) == [60])
        let blue = try #require(snapshot.verticalRuns(x: 275, Self.blue).first)
        #expect(blue.1 == 30)
        #expect(blue.0 == 15)
    }

    @Test("a percentage whose content is taller than the row's basis grows the row to that content")
    func tallShareGrowsRow() async throws {
        let snapshot = try await render(grid(width: "300", items: [
            #"{"size": {"width": "100%", "height": 20}, "view": \#(Self.fill("#FF0000"))}"#,
            #"{"size": {"width": "100%", "height": "50%"}, "view": \#(Self.longLabel)}"#,
        ]), constraints: bounded)

        // The first column is the 20pt red box centred on grid background, so red plus green is the row.
        let green = snapshot.verticalRuns(x: 55, Self.green)
        let red = try #require(snapshot.verticalRuns(x: 55, Self.red).first)
        let rowHeight = red.1 + green.reduce(0) { $0 + $1.1 }
        #expect(red.1 == 20)
        #expect(rowHeight > 40)
        #expect(abs(Double(red.0) - Double(rowHeight - 20) / 2) <= 1)

        // The cell's trailing edge, clear of the centred text.
        let blue = try #require(snapshot.verticalRuns(x: 348, Self.blue).first)
        #expect(blue.0 == 0)
        #expect(abs(blue.1 - rowHeight) <= 1)
    }

    @Test("an auto grid beside a label in a horizontal stack divides the width left to it")
    func autoGridBesideLabel() async throws {
        let json = #"""
        {"type": "linear_layout", "direction": "horizontal", "items": [
          {"size": {"width": "auto", "height": "auto"}, "view": {
            "type": "grid_layout",
            "config": {"default": {"max_columns": 3, "column_spacing": 10}},
            "items": [
              {"size": {"width": "100%", "height": 20}, "view": \#(Self.fill("#FF0000"))},
              {"size": {"width": "100%", "height": 20}, "view": \#(Self.fill("#FF0000"))},
              {"size": {"width": "100%", "height": 20}, "view": \#(Self.fill("#FF0000"))}
            ]
          }},
          {"size": {"width": 100, "height": 20}, "view": \#(Self.fill("#0000FF"))}
        ]}
        """#
        let snapshot = try await render(json, constraints: bounded)

        // The horizontal stack centres its 20pt row in the 400pt frame.
        let tiles = snapshot.horizontalRuns(y: 200, Self.red)
        #expect(tiles.count == 3)
        // 400 less the 100pt sibling leaves 300: (300 - 2 * 10) / 3 each.
        for tile in tiles {
            #expect(abs(Double(tile.1) - 280.0 / 3) <= 1)
        }
        #expect(snapshot.horizontalRuns(y: 200, Self.blue).first?.0 == 300)
    }

    @Test("an auto grid's border comes out of the width it divides, once")
    func autoGridBorder() async throws {
        let json = #"""
        {"type": "linear_layout", "direction": "vertical", "items": [{
          "size": {"width": "auto", "height": "auto"},
          "view": {"type": "grid_layout",
            "border": {"stroke_width": 4, "stroke_color": {"default": {"type": "hex", "hex": "#00FF00", "alpha": 1}}},
            "config": {"default": {"max_columns": 2}},
            "items": [
              {"size": {"width": "100%", "height": 20}, "view": \#(Self.fill("#FF0000"))},
              {"size": {"width": "100%", "height": 20}, "view": \#(Self.fill("#0000FF"))}
            ]}
        }]}
        """#
        let snapshot = try await render(json, constraints: ViewConstraints(width: 300, height: Self.size.height))

        // 300 less the 4pt stroke each side leaves 292, so two columns of 146.
        let red = try #require(snapshot.horizontalRuns(y: 14, Self.red).first)
        #expect(red.0 == 4)
        #expect(red.1 == 146)
        #expect(snapshot.horizontalRuns(y: 14, Self.blue).first?.1 == 146)
    }
}

#endif
