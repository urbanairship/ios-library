/* Copyright Airship and Contributors */

#if !os(macOS) && !os(watchOS) && !os(tvOS)

import Foundation
import Combine
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
    private func render(
        _ json: String,
        constraints: ViewConstraints,
        environment: ThomasEnvironment? = nil,
        layoutDirection: LayoutDirection = .leftToRight
    ) async throws -> Snapshot {
        let renderer = try makeRenderer(json, constraints: constraints, environment: environment, layoutDirection: layoutDirection)
        return try await settle(renderer)
    }

    /// Snapshots `json` once it settles, then again after `change` on the same view, so measurements it keeps carry over.
    private func render(
        _ json: String,
        constraints: ViewConstraints,
        state: ThomasState,
        change: () -> Void
    ) async throws -> (before: Snapshot, after: Snapshot) {
        let renderer = try makeRenderer(json, constraints: constraints, state: state)
        let before = try await settle(renderer)
        change()
        return (before, try await settle(renderer))
    }

    private func makeRenderer(
        _ json: String,
        constraints: ViewConstraints,
        environment: ThomasEnvironment? = nil,
        state: ThomasState? = nil,
        layoutDirection: LayoutDirection = .leftToRight
    ) throws -> ImageRenderer<some View> {
        let thomasEnvironment = environment ?? self.thomasEnvironment
        let view = try JSONDecoder().decode(ThomasViewInfo.self, from: Data(json.utf8))
        let content = thomasEnvironment.viewFactory.createView(view, constraints: constraints)
            .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
            .background(Color.white)
            .environment(\.layoutDirection, layoutDirection)
            .environmentObject(thomasEnvironment)
            .environmentObject(state ?? thomasState)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        return renderer
    }

    private func settle(_ renderer: ImageRenderer<some View>) async throws -> Snapshot {
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

    private func grid(width: String, items: [String], config: String = #"{"columns": {"type": "fixed", "count": 2}}"#) -> String {
        #"""
        {"type": "linear_layout", "direction": "vertical", "items": [{
          "size": {"width": \#(width), "height": "auto"},
          "view": {
            "type": "grid_layout", "identifier": "grid-1",
            "background_color": {"default": {"type": "hex", "hex": "#00FF00", "alpha": 1}},
            "config": \#(config),
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
            "type": "grid_layout", "identifier": "grid-2",
            "config": {"columns": {"type": "fit", "max": 3, "min_width": {"type": "fixed", "size": 40}}, "column_spacing": {"type": "fixed", "space": 8}},
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

    private static let cappedColumns = #"{"type": "fit", "max": 4, "min_width": {"type": "fixed", "size": 44}, "max_width": {"type": "fixed", "size": 64}}"#

    private func tiles(_ count: Int) -> [String] {
        Array(repeating: #"{"size": {"width": "100%", "height": 20}, "view": \#(Self.fill("#FF0000"))}"#, count: count)
    }

    @Test("capped columns stop at max_width and content_position centres them")
    func cappedColumnsCentred() async throws {
        let snapshot = try await render(grid(
            width: "400",
            items: tiles(4),
            config: #"{"columns": \#(Self.cappedColumns), "column_spacing": {"type": "fixed", "space": 8}, "content_position": {"horizontal": "center", "vertical": "top"}}"#
        ), constraints: bounded)

        // Four 64pt columns 8 apart are 280 wide, leaving 60 either side of a 400pt grid.
        let runs = snapshot.horizontalRuns(y: 10, Self.red)
        #expect(runs.map(\.1) == [64, 64, 64, 64])
        #expect(runs.map(\.0) == [60, 132, 204, 276])
    }

    @Test("a short row aligns among the capped columns, not the whole grid")
    func shortRowAlignsWithinBlock() async throws {
        let snapshot = try await render(grid(
            width: "400",
            items: tiles(7),
            config: #"{"columns": \#(Self.cappedColumns), "column_spacing": {"type": "fixed", "space": 8}, "row_spacing": {"type": "fixed", "space": 8}, "partial_row_position": "end", "content_position": {"horizontal": "start", "vertical": "top"}}"#
        ), constraints: bounded)

        let fullRow = snapshot.horizontalRuns(y: 10, Self.red)
        let shortRow = snapshot.horizontalRuns(y: 38, Self.red)
        #expect(fullRow.count == 4)
        #expect(shortRow.count == 3)
        // Both rows end at the block's trailing edge, 280pt in, rather than the grid's at 400.
        #expect(fullRow.last.map { $0.0 + $0.1 } == 280)
        #expect(shortRow.last.map { $0.0 + $0.1 } == 280)
    }

    private func edgeGrid(width: Int, config: String, header: String?, footer: String?, items: [String]) -> String {
        let edges = [header.map { #""header": \#($0)"# }, footer.map { #""footer": \#($0)"# }]
            .compactMap { $0 }
            .map { $0 + "," }
            .joined()
        return #"""
        {"type": "linear_layout", "direction": "vertical", "items": [{
          "size": {"width": \#(width), "height": "auto"},
          "view": {
            "type": "grid_layout", "identifier": "grid-3",
            "background_color": {"default": {"type": "hex", "hex": "#00FF00", "alpha": 1}},
            "config": \#(config),
            \#(edges)
            "items": [\#(items.joined(separator: ","))]
          }
        }]}
        """#
    }

    private static func edge(_ hex: String, height: Int) -> String {
        #"{"size": {"width": "100%", "height": \#(height)}, "view": \#(fill(hex))}"#
    }

    @Test("a header and footer line up with a capped block's edges, separated by row_spacing")
    func edgesMatchBlock() async throws {
        let snapshot = try await render(edgeGrid(
            width: 400,
            config: #"{"columns": \#(Self.cappedColumns), "column_spacing": {"type": "fixed", "space": 8}, "row_spacing": {"type": "fixed", "space": 6}, "content_position": {"horizontal": "center", "vertical": "top"}}"#,
            header: Self.edge("#0000FF", height: 12),
            footer: Self.edge("#0000FF", height: 12),
            items: tiles(4)
        ), constraints: bounded)

        // The block is four 64pt columns 8 apart, 280 wide from x = 60.
        let headerRun = try #require(snapshot.horizontalRuns(y: 5, Self.blue).first)
        #expect(headerRun.0 == 60)
        #expect(headerRun.1 == 280)

        // Header 12, gap 6, cells 20, gap 6, footer 12.
        #expect(snapshot.verticalRuns(x: 90, Self.blue).map { [$0.0, $0.1] } == [[0, 12], [44, 12]])
        #expect(snapshot.verticalRuns(x: 90, Self.red).map { [$0.0, $0.1] } == [[18, 20]])
    }

    @Test("a header keeps its own height beside rows a ratio sets")
    func edgeKeepsOwnHeight() async throws {
        let snapshot = try await render(edgeGrid(
            width: 300,
            config: #"{"columns": {"type": "fixed", "count": 3}, "cell_aspect_ratio": 1}"#,
            header: Self.edge("#0000FF", height: 20),
            footer: nil,
            items: tiles(3)
        ), constraints: bounded)

        #expect(snapshot.verticalRuns(x: 55, Self.blue).map(\.1) == [20])
        // The 20pt tile sits centred in its 100pt ratio row under the header.
        #expect(snapshot.verticalRuns(x: 55, Self.red).map { [$0.0, $0.1] } == [[60, 20]])
    }

    @Test("a hidden header leaves no row")
    func hiddenEdgeLeavesNoRow() async throws {
        let hidden = #"""
        {"size": {"width": "100%", "height": 20}, "view": {
          "type": "empty_view",
          "background_color": {"default": {"type": "hex", "hex": "#0000FF", "alpha": 1}},
          "visibility": {"default": false, "invert_when_state_matches": {"key": "show", "value": {"is_present": true}}}
        }}
        """#
        let snapshot = try await render(edgeGrid(
            width: 300,
            config: #"{"columns": {"type": "fixed", "count": 3}, "row_spacing": {"type": "fixed", "space": 10}}"#,
            header: hidden,
            footer: nil,
            items: tiles(3)
        ), constraints: bounded)

        #expect(snapshot.verticalRuns(x: 55, Self.blue).isEmpty)
        #expect(snapshot.verticalRuns(x: 55, Self.red).first?.0 == 0)
    }

    @Test("a container item with an aspect_ratio fills its ratio box, its border drawn inside")
    func containerFillsRatioBox() async throws {
        let box = #"""
        {"size": {"width": "100%", "height": "auto", "aspect_ratio": 1}, "view": {
          "type": "container",
          "background_color": {"default": {"type": "hex", "hex": "#0000FF", "alpha": 1}},
          "border": {"stroke_width": 5, "stroke_color": {"default": {"type": "hex", "hex": "#FF0000", "alpha": 1}}},
          "items": []
        }}
        """#
        let snapshot = try await render(grid(
            width: "300",
            items: [box, box, box],
            config: #"{"columns": {"type": "fixed", "count": 3}}"#
        ), constraints: bounded)

        // The grid is centred at x = 50; the first box is 100 square with a 5pt stroke inside it.
        #expect(snapshot.verticalRuns(x: 52, Self.red).map { [$0.0, $0.1] } == [[0, 100]])
        #expect(snapshot.verticalRuns(x: 100, Self.blue).map { [$0.0, $0.1] } == [[5, 90]])
    }

    @Test("spread spacing widens capped columns' gaps so full rows reach both edges")
    func spreadColumnGaps() async throws {
        let snapshot = try await render(grid(
            width: "340",
            items: tiles(7),
            config: #"{"columns": \#(Self.cappedColumns), "column_spacing": {"type": "spread", "min_space": 6}, "row_spacing": {"type": "fixed", "space": 8}, "partial_row_position": "center"}"#
        ), constraints: bounded)

        // The 340pt grid is centred in the 400pt stack, from x = 30. Four columns of 64 leave 84, so gaps of 28.
        #expect(snapshot.horizontalRuns(y: 10, Self.red).map { [$0.0 - 30, $0.1] } == [[0, 64], [92, 64], [184, 64], [276, 64]])
        // The short row of 3 starts half a column in: (64 + 28) / 2.
        #expect(snapshot.horizontalRuns(y: 38, Self.red).first.map { $0.0 - 30 } == 46)
    }

    @Test("spread column gaps stop at max_space, and content_position places what's left")
    func spreadColumnMaxSpace() async throws {
        let snapshot = try await render(grid(
            width: "340",
            items: tiles(4),
            config: #"{"columns": \#(Self.cappedColumns), "column_spacing": {"type": "spread", "min_space": 6, "max_space": 20}, "content_position": {"horizontal": "center", "vertical": "top"}}"#
        ), constraints: bounded)

        // Gaps of 20 make a 316pt block, centred 12 in from the grid's start at x = 30.
        #expect(snapshot.horizontalRuns(y: 10, Self.red).map { $0.0 - 30 } == [12, 96, 180, 264])
    }

    private func tallGrid(rowSpacing: String, vertical: String = "top") -> String {
        #"""
        {"type": "linear_layout", "direction": "vertical", "items": [{
          "size": {"width": 300, "height": 300},
          "view": {
            "type": "grid_layout", "identifier": "grid-4",
            "config": {"columns": {"type": "fixed", "count": 4}, "row_spacing": \#(rowSpacing), "content_position": {"horizontal": "start", "vertical": "\#(vertical)"}},
            "items": [\#(Array(repeating: #"{"size": {"width": "100%", "height": 32}, "view": \#(Self.fill("#FF0000"))}"#, count: 12).joined(separator: ","))]
          }
        }]}
        """#
    }

    @Test("spread rows share a height the grid has of its own")
    func spreadRows() async throws {
        let snapshot = try await render(tallGrid(rowSpacing: #"{"type": "spread", "min_space": 8}"#), constraints: bounded)

        // Three 32pt rows leave 204 of 300, so gaps of 102.
        #expect(snapshot.verticalRuns(x: 60, Self.red).map(\.0) == [0, 134, 268])
    }

    @Test("spread rows stop at max_space, with the rest placed by content_position")
    func spreadRowsMaxSpace() async throws {
        let snapshot = try await render(
            tallGrid(rowSpacing: #"{"type": "spread", "min_space": 8, "max_space": 40}"#, vertical: "center"),
            constraints: bounded
        )

        // Gaps of 40 make a 176pt block, centred 62 down.
        #expect(snapshot.verticalRuns(x: 60, Self.red).map(\.0) == [62, 134, 206])
    }

    @Test("an item's order moves it among its siblings")
    func itemOrder() async throws {
        let snapshot = try await render(grid(
            width: "300",
            items: [
                #"{"config": {"order": 1}, "size": {"width": "100%", "height": 20}, "view": \#(Self.fill("#0000FF"))}"#,
                #"{"size": {"width": "100%", "height": 20}, "view": \#(Self.fill("#FF0000"))}"#,
                #"{"size": {"width": "100%", "height": 20}, "view": \#(Self.fill("#FF0000"))}"#,
            ],
            config: #"{"columns": {"type": "fixed", "count": 3}}"#
        ), constraints: bounded)

        // Listed first, the blue item at order 1 places last: the third 100pt column, from x = 50 + 200.
        #expect(snapshot.horizontalRuns(y: 10, Self.blue).map { [$0.0, $0.1] } == [[250, 100]])
        #expect(snapshot.horizontalRuns(y: 10, Self.red).map { [$0.0, $0.1] } == [[50, 200]])
    }

    @Test("a randomize_children order holds for the scene, however often the grid is rebuilt")
    func shuffleHoldsForScene() async throws {
        let colors: [(hex: String, rgb: (Int, Int, Int))] = [
            ("#FF0000", (255, 0, 0)), ("#00FF00", (0, 255, 0)), ("#0000FF", (0, 0, 255)),
            ("#FFFF00", (255, 255, 0)), ("#FF00FF", (255, 0, 255)), ("#00FFFF", (0, 255, 255)),
        ]
        let items = colors.map { #"{"size": {"width": "100%", "height": 20}, "view": \#(Self.fill($0.hex))}"# }
        let json = #"""
        {"type": "linear_layout", "direction": "vertical", "items": [{
          "size": {"width": 360, "height": "auto"},
          "view": {"type": "grid_layout", "identifier": "grid-5", "randomize_children": true,
            "config": {"columns": {"type": "fixed", "count": 6}},
            "items": [\#(items.joined(separator: ","))]}
        }]}
        """#

        // Each render builds the grid afresh, as a pager does a page it comes back to.
        var orders: [[Int]] = []
        for _ in 0..<5 {
            let snapshot = try await render(json, constraints: bounded)
            let starts = colors.map { snapshot.horizontalRuns(y: 10, $0.rgb).first?.0 ?? -1 }
            orders.append(colors.indices.sorted { starts[$0] < starts[$1] })
        }
        #expect(Set(orders.map { $0.description }).count == 1)
        #expect(Set(orders[0]) == Set(colors.indices))
    }

    @Test("a linear layout's randomize_children order holds for the scene, however often it is rebuilt")
    func linearShuffleHoldsForScene() async throws {
        let colors: [(hex: String, rgb: (Int, Int, Int))] = [
            ("#FF0000", (255, 0, 0)), ("#00FF00", (0, 255, 0)), ("#0000FF", (0, 0, 255)),
            ("#FFFF00", (255, 255, 0)), ("#FF00FF", (255, 0, 255)), ("#00FFFF", (0, 255, 255)),
        ]
        let items = colors.map { #"{"size": {"width": 60, "height": 20}, "view": \#(Self.fill($0.hex))}"# }
        let json = #"""
        {"type": "linear_layout", "direction": "horizontal", "randomize_children": true,
         "items": [\#(items.joined(separator: ","))]}
        """#

        var orders: [[Int]] = []
        for _ in 0..<5 {
            let snapshot = try await render(json, constraints: bounded)
            let starts = colors.map { color in
                (0..<Int(Self.size.height)).lazy.compactMap { snapshot.horizontalRuns(y: $0, color.rgb).first?.0 }.first ?? -1
            }
            orders.append(colors.indices.sorted { starts[$0] < starts[$1] })
        }
        #expect(Set(orders.map { $0.description }).count == 1)
        #expect(Set(orders[0]) == Set(colors.indices))
    }

    private static let sixColors: [(hex: String, rgb: (Int, Int, Int))] = [
        ("#FF0000", (255, 0, 0)), ("#00FF00", (0, 255, 0)), ("#0000FF", (0, 0, 255)),
        ("#FFFF00", (255, 255, 0)), ("#FF00FF", (255, 0, 255)), ("#00FFFF", (0, 255, 255)),
    ]

    /// The indices of `colors`, left to right by where each first appears.
    private static func horizontalOrder(_ snapshot: Snapshot, _ colors: [(hex: String, rgb: (Int, Int, Int))]) -> [Int] {
        let starts = colors.map { color in
            (0..<snapshot.height).lazy.compactMap { snapshot.horizontalRuns(y: $0, color.rgb).first?.0 }.first ?? -1
        }
        return colors.indices.sorted { starts[$0] < starts[$1] }
    }

    @Test("a seeded linear layout shuffles to the order every platform gives its key")
    func seededLinearShuffle() async throws {
        let items = Self.sixColors.map { #"{"size": {"width": 60, "height": 20}, "view": \#(Self.fill($0.hex))}"# }
        let json = #"""
        {"type": "linear_layout", "identifier": "colors", "direction": "horizontal", "randomize_children": true,
         "items": [\#(items.joined(separator: ","))]}
        """#
        let environment = ThomasEnvironment(
            delegate: StubThomasDelegate(),
            extensions: TestThomasExtensions(randomSeed: SeededShuffle.uiTestSeed)
        )
        let snapshot = try await render(json, constraints: bounded, environment: environment)

        // ui-test:colors:6 → 5, 4, 3, 0, 1, 2
        #expect(Self.horizontalOrder(snapshot, Self.sixColors) == [5, 4, 3, 0, 1, 2])
    }

    @Test("linear layout items lay out by order, an override's order replacing the config's")
    func linearItemOrder() async throws {
        let colors = Array(Self.sixColors.prefix(3))
        let json = #"""
        {"type": "linear_layout", "direction": "horizontal", "items": [
          {"size": {"width": 60, "height": 20}, "config": {"order": 1}, "view": \#(Self.fill(colors[0].hex))},
          {"size": {"width": 60, "height": 20}, "view": \#(Self.fill(colors[1].hex))},
          {"size": {"width": 60, "height": 20}, "config": {"order": 2},
           "overrides": {"config": [{"value": {"order": -1}}]}, "view": \#(Self.fill(colors[2].hex))}
        ]}
        """#
        let snapshot = try await render(json, constraints: bounded)

        #expect(Self.horizontalOrder(snapshot, colors) == [2, 1, 0])
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
            "type": "grid_layout", "identifier": "grid-6",
            "config": {"columns": {"type": "fixed", "count": 3}, "column_spacing": {"type": "fixed", "space": 10}},
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
          "view": {"type": "grid_layout", "identifier": "grid-7",
            "border": {"stroke_width": 4, "stroke_color": {"default": {"type": "hex", "hex": "#00FF00", "alpha": 1}}},
            "config": {"columns": {"type": "fixed", "count": 2}},
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

    /// A 20pt-tall fill shown only while `$grids.current.width` is in `range`.
    private static func shownWhenGridWidth(_ range: String, hex: String) -> String {
        #"""
        {"size": {"width": "100%", "height": 20}, "view": {
          "type": "empty_view",
          "background_color": {"default": {"type": "hex", "hex": "\#(hex)", "alpha": 1}},
          "visibility": {"default": false, "invert_when_state_matches": {"scope": ["$grids", "current", "width"], "value": \#(range)}}
        }}
        """#
    }

    @Test("the grid, its items' placement and the views in its cells see its width")
    func gridWidthReachesGridAndCells() async throws {
        let json = #"""
        {"type": "linear_layout", "direction": "vertical", "items": [{
          "size": {"width": 300, "height": "auto"},
          "view": {
            "type": "grid_layout", "identifier": "grid",
            "background_color": {"default": {"type": "hex", "hex": "#00FF00", "alpha": 1}},
            "visibility": {"default": false, "invert_when_state_matches": {"scope": ["$grids", "current", "width"], "value": {"at_least": 300}}},
            "config": {"columns": {"type": "fixed", "count": 2}},
            "items": [
              \#(Self.shownWhenGridWidth(#"{"at_most": 200}"#, hex: "#0000FF")),
              \#(Self.shownWhenGridWidth(#"{"at_least": 300}"#, hex: "#FF0000"))
            ]
          }
        }]}
        """#
        let snapshot = try await render(json, constraints: bounded)

        // The 300pt grid sits centred in the window. The hidden item takes no place, so the shown one
        // starts the row and the grid's background fills the rest.
        #expect(snapshot.horizontalRuns(y: 10, Self.red).map { [$0.0, $0.1] } == [[50, 150]])
        #expect(snapshot.horizontalRuns(y: 10, Self.green).map { [$0.0, $0.1] } == [[200, 150]])
        #expect(snapshot.horizontalRuns(y: 10, Self.blue).isEmpty)
    }

    @MainActor
    private final class ResizableWidth: ObservableObject {
        @Published var width: CGFloat = 400
    }

    private struct ResizableHost: View {
        let view: ThomasViewInfo
        let environment: ThomasEnvironment
        @ObservedObject var model: ResizableWidth

        var body: some View {
            environment.viewFactory
                .createView(view, constraints: ViewConstraints(width: model.width, height: Self.height))
                .frame(width: GridLayoutRenderingTest.size.width, height: Self.height, alignment: .topLeading)
                .background(Color.white)
        }

        private static let height: CGFloat = GridLayoutRenderingTest.size.height
    }

    @Test("an auto grid's column count follows a new offer on the first pass, not a pass later")
    func columnCountFollowsNewOffer() async throws {
        // The blue fill marks the first pass laid out at the new offer.
        let json = #"""
        {"type": "linear_layout", "direction": "vertical", "items": [{
          "size": {"width": "auto", "height": "auto"},
          "view": {
            "type": "grid_layout", "identifier": "grid",
            "config": {"columns": {"type": "fit", "max": 10, "min_width": {"type": "fixed", "size": 100}}},
            "items": [{"size": {"width": "100%", "height": 20}, "view": \#(Self.fill("#FF0000"))}]
          }
        }, {"size": {"width": "100%", "height": 20}, "view": \#(Self.fill("#0000FF"))}]}
        """#
        let view = try JSONDecoder().decode(ThomasViewInfo.self, from: Data(json.utf8))
        let model = ResizableWidth()
        let renderer = ImageRenderer(
            content: ResizableHost(view: view, environment: thomasEnvironment, model: model)
                .environment(\.layoutDirection, .leftToRight)
                .environmentObject(thomasEnvironment)
                .environmentObject(thomasState)
        )
        renderer.scale = 1

        func snapshot() throws -> Snapshot {
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

        for _ in 0..<6 {
            _ = renderer.cgImage
            try await Task.sleep(for: .milliseconds(30))
        }
        // 4 columns of 100 fit in 400.
        #expect(try snapshot().horizontalRuns(y: 10, Self.red).first?.1 == 100)

        model.width = 300
        var firstPass: Snapshot?
        for _ in 0..<50 {
            let frame = try snapshot()
            if frame.horizontalRuns(y: 30, Self.blue).first?.1 == 300 {
                firstPass = frame
                break
            }
            await Task.yield()
        }
        // 3 columns of 100 fit in 300; the 400 measurement would still draw 4 of 75.
        #expect(try #require(firstPass).horizontalRuns(y: 10, Self.red).first?.1 == 100)
    }

    @Test(
        "$grids.current.width is the content width inside the border drawn, an override's included",
        arguments: ["360", "\"auto\""]
    )
    func gridWidthIsInsideDrawnBorder(width: String) async throws {
        let json = #"""
        {"type": "linear_layout", "direction": "vertical", "items": [{
          "size": {"width": \#(width), "height": "auto"},
          "view": {
            "type": "grid_layout", "identifier": "grid",
            "border": {"stroke_width": 4, "stroke_color": {"default": {"type": "hex", "hex": "#00FF00", "alpha": 1}}},
            "view_overrides": {"border": [{
              "when_state_matches": {"key": "unset", "value": {"is_present": false}},
              "value": {"stroke_width": 12, "stroke_color": {"default": {"type": "hex", "hex": "#00FF00", "alpha": 1}}}
            }]},
            "config": {"columns": {"type": "fixed", "count": 1}},
            "items": [\#(Self.shownWhenGridWidth(#"{"at_least": 336, "at_most": 336}"#, hex: "#FF0000"))]
          }
        }]}
        """#
        let snapshot = try await render(json, constraints: ViewConstraints(width: 360, height: Self.size.height))

        // 360 less the 12pt drawn stroke each side.
        #expect(snapshot.horizontalRuns(y: 20, Self.red).map { [$0.0, $0.1] } == [[12, 336]])
    }

    @Test("a nested grid's width takes over for the views inside it")
    func nestedGridTakesOver() async throws {
        let json = #"""
        {"type": "linear_layout", "direction": "vertical", "items": [{
          "size": {"width": 300, "height": "auto"},
          "view": {
            "type": "grid_layout", "identifier": "outer",
            "config": {"columns": {"type": "fixed", "count": 2}},
            "items": [
              \#(Self.shownWhenGridWidth(#"{"at_least": 300}"#, hex: "#FF0000")),
              {"view": {
                "type": "grid_layout", "identifier": "inner",
                "config": {"columns": {"type": "fixed", "count": 1}},
                "items": [\#(Self.shownWhenGridWidth(#"{"at_most": 200}"#, hex: "#0000FF"))]
              }}
            ]
          }
        }]}
        """#
        let snapshot = try await render(json, constraints: bounded)

        // The 300pt outer grid sits centred in the window; the inner grid is its second 150pt cell.
        #expect(snapshot.horizontalRuns(y: 10, Self.red).map { [$0.0, $0.1] } == [[50, 150]])
        #expect(snapshot.horizontalRuns(y: 10, Self.blue).map { [$0.0, $0.1] } == [[200, 150]])
    }

    // MARK: column_start

    /// A 360pt grid of 12 columns, 30pt each, centred in the 400pt stack from x = 20.
    private func twelveColumns(_ items: [String]) -> String {
        grid(width: "360", items: items, config: #"{"columns": {"type": "fixed", "count": 12}}"#)
    }

    @Test("column_start centres an 8-of-12 card")
    func columnStartCentres() async throws {
        let snapshot = try await render(twelveColumns([
            #"{"size": {"width": "100%", "height": 20}, "config": {"column_span": 8, "column_start": 2}, "view": \#(Self.fill("#FF0000"))}"#,
        ]), constraints: bounded)

        // Columns 2 to 9: 60pt in from the grid's left edge, 240 wide.
        #expect(snapshot.horizontalRuns(y: 10, Self.red).map { [$0.0, $0.1] } == [[80, 240]])
    }

    @Test("column_start counts from the right in RTL")
    func columnStartRTL() async throws {
        let snapshot = try await render(twelveColumns([
            #"{"size": {"width": "100%", "height": 20}, "config": {"column_span": 4, "column_start": 1}, "view": \#(Self.fill("#FF0000"))}"#,
        ]), constraints: bounded, layoutDirection: .rightToLeft)

        // One column in from the grid's right edge at 380: 230 to 350.
        #expect(snapshot.horizontalRuns(y: 10, Self.red).map { [$0.0, $0.1] } == [[230, 120]])
    }

    @Test("a short row starts at the right edge in RTL")
    func shortRowRTL() async throws {
        let snapshot = try await render(twelveColumns([
            #"{"size": {"width": "100%", "height": 20}, "config": {"column_span": 4}, "view": \#(Self.fill("#FF0000"))}"#,
        ]), constraints: bounded, layoutDirection: .rightToLeft)

        // The first four columns from the grid's right edge at 380.
        #expect(snapshot.horizontalRuns(y: 10, Self.red).map { [$0.0, $0.1] } == [[260, 120]])
    }

    @Test("column_start follows an override on the grid's width")
    func columnStartOverride() async throws {
        let snapshot = try await render(twelveColumns([
            #"""
            {"size": {"width": "100%", "height": 20}, "config": {"column_span": 8, "column_start": 2},
             "overrides": {"config": [{"when_state_matches": {"scope": ["$grids", "current", "width"], "value": {"at_most": 400}},
                                       "value": {"column_span": 4, "column_start": 4}}]},
             "view": \#(Self.fill("#FF0000"))}
            """#,
        ]), constraints: bounded)

        // Columns 4 to 7, so both the overriding span and start are read.
        #expect(snapshot.horizontalRuns(y: 10, Self.red).map { [$0.0, $0.1] } == [[140, 120]])
    }

    // MARK: percent_height_basis

    private static let yellow = (255, 255, 0)
    private static let magenta = (255, 0, 255)

    /// A card filled `hex`, as tall as `height` points of filler inside it.
    private static func card(_ hex: String, _ height: Int, filler: String = "") -> String {
        #"""
        {"type": "linear_layout", "direction": "vertical",
         "background_color": {"default": {"type": "hex", "hex": "\#(hex)", "alpha": 1}},
         "items": [{"size": {"width": "100%", "height": \#(height)}, "view": {"type": "empty_view"\#(filler)}}]}
        """#
    }

    private static func item(_ view: String, height: String = #""100%""#, span: Int = 1) -> String {
        #"{"size": {"width": "100%", "height": \#(height)}, "config": {"column_span": \#(span)}, "view": \#(view)}"#
    }

    /// Two 200pt columns with 8pt between rows, pooling percentage rows when `tallest` is set.
    private func cards(_ items: [String], tallest: Bool = true, height: String = #""auto""#) -> String {
        let basis = tallest ? #", "percent_height_basis": "tallest_row""# : ""
        return #"""
        {"type": "linear_layout", "direction": "vertical", "items": [{
          "size": {"width": 400, "height": \#(height)},
          "view": {
            "type": "grid_layout", "identifier": "grid-cards",
            "config": {"columns": {"type": "fixed", "count": 2}, "row_spacing": {"type": "fixed", "space": 8}\#(basis)},
            "items": [\#(items.joined(separator: ","))]
          }
        }]}
        """#
    }

    /// The height of each `color` card down column `x`, top to bottom.
    private static func heights(_ snapshot: Snapshot, x: Int, _ color: (Int, Int, Int)) -> [Int] {
        snapshot.verticalRuns(x: x, color).map(\.1)
    }

    @Test("tallest_row gives every 100% card the tallest card's height")
    func tallestRowEqualCards() async throws {
        let snapshot = try await render(cards([
            Self.item(Self.card("#FF0000", 20)), Self.item(Self.card("#0000FF", 80)),
            Self.item(Self.card("#FFFF00", 40)), Self.item(Self.card("#FF00FF", 10)),
        ]), constraints: bounded)

        #expect(Self.heights(snapshot, x: 100, Self.red) == [80])
        #expect(Self.heights(snapshot, x: 300, Self.blue) == [80])
        #expect(Self.heights(snapshot, x: 100, Self.yellow) == [80])
        #expect(Self.heights(snapshot, x: 300, Self.magenta) == [80])
    }

    @Test("without percent_height_basis each row keeps its own height")
    func rowBasisByDefault() async throws {
        let snapshot = try await render(cards([
            Self.item(Self.card("#FF0000", 20)), Self.item(Self.card("#0000FF", 80)),
            Self.item(Self.card("#FFFF00", 40)), Self.item(Self.card("#FF00FF", 10)),
        ], tallest: false), constraints: bounded)

        #expect(Self.heights(snapshot, x: 100, Self.red) == [80])
        #expect(Self.heights(snapshot, x: 100, Self.yellow) == [40])
        #expect(Self.heights(snapshot, x: 300, Self.magenta) == [40])
    }

    @Test("tallest_row leaves a row of only auto cells at its own height")
    func tallestRowKeepsAutoRow() async throws {
        let snapshot = try await render(cards([
            Self.item(Self.card("#FF0000", 20)), Self.item(Self.card("#0000FF", 30)),
            Self.item(Self.card("#FFFF00", 120), height: #""auto""#, span: 2),
        ]), constraints: bounded)

        #expect(Self.heights(snapshot, x: 100, Self.red) == [30])
        #expect(Self.heights(snapshot, x: 300, Self.blue) == [30])
        #expect(Self.heights(snapshot, x: 100, Self.yellow) == [120])
    }

    @Test("tallest_row resolves a share under 100% against the tallest row")
    func tallestRowHalfShare() async throws {
        let snapshot = try await render(cards([
            // A fixed height gives the pooled rows a basis: H is 100.
            Self.item(Self.fill("#00FFFF"), height: "100"), Self.item(Self.card("#FF0000", 10)),
            Self.item(Self.card("#0000FF", 10), height: #""50%""#), Self.item(Self.card("#FFFF00", 10)),
        ]), constraints: bounded)

        #expect(Self.heights(snapshot, x: 300, Self.red) == [100])
        #expect(Self.heights(snapshot, x: 100, Self.blue) == [50])
        #expect(Self.heights(snapshot, x: 300, Self.yellow) == [100])
    }

    @Test("tallest_row keeps a share under 100% at least as tall as its content")
    func tallestRowShareFloorsAtContent() async throws {
        let snapshot = try await render(cards([
            // A fixed height gives the pooled rows a basis; the 50% card's content is the tallest.
            Self.item(Self.fill("#00FFFF"), height: "20"), Self.item(Self.card("#FF0000", 40)),
            Self.item(Self.card("#0000FF", 80), height: #""50%""#), Self.item(Self.card("#FFFF00", 10)),
        ]), constraints: bounded)

        #expect(Self.heights(snapshot, x: 100, Self.blue) == [80])
        #expect(Self.heights(snapshot, x: 300, Self.yellow) == [80])
    }

    @Test("tallest_row keeps a share under 100% at least as tall as its wrapping label")
    func tallestRowShareFloorsAtLabel() async throws {
        let label = #"""
        {"type": "label", "text": "A much longer body that wraps across several lines inside its narrow grid cell for sure",
         "text_appearance": {"font_size": 14, "color": {"default": {"type": "hex", "hex": "#000000", "alpha": 1}}},
         "background_color": {"default": {"type": "hex", "hex": "#FF0000", "alpha": 1}}}
        """#
        let snapshot = try await render(cards([
            Self.item(Self.fill("#00FFFF"), height: "20"), Self.item(Self.card("#0000FF", 10)),
            Self.item(label, height: #""50%""#), Self.item(Self.card("#FFFF00", 10)),
        ]), constraints: bounded)

        // Text can split the label's fill, so measure from its first red pixel to its last.
        let runs = snapshot.verticalRuns(x: 199, Self.red)
        let labelHeight = runs.last.map { $0.0 + $0.1 - runs[0].0 }
        // The label's wrapped text sets the pooled height, so its 50% share can't be less than that.
        #expect(labelHeight == Self.heights(snapshot, x: 300, Self.yellow).first)
    }

    @Test("tallest_row caps a share over 100% at the tallest row")
    func tallestRowCapsShare() async throws {
        let snapshot = try await render(cards([
            Self.item(Self.card("#FF0000", 40)), Self.item(Self.card("#0000FF", 10), height: #""200%""#),
        ]), constraints: bounded)

        #expect(Self.heights(snapshot, x: 100, Self.red) == [40])
        #expect(Self.heights(snapshot, x: 300, Self.blue) == [40])
    }

    @Test("tallest_row ignores the grid's own height")
    func tallestRowIgnoresGridHeight() async throws {
        let snapshot = try await render(cards([
            Self.item(Self.card("#FF0000", 20)), Self.item(Self.card("#0000FF", 40)),
            Self.item(Self.card("#FFFF00", 10)),
        ], height: "300"), constraints: bounded)

        #expect(Self.heights(snapshot, x: 100, Self.red) == [40])
        #expect(Self.heights(snapshot, x: 300, Self.blue) == [40])
        #expect(Self.heights(snapshot, x: 100, Self.yellow) == [40])
    }

    @Test("tallest_row shrinks when the tallest card's content does")
    func tallestRowShrinks() async throws {
        let hideWhenSmall = #", "visibility": {"default": true, "invert_when_state_matches": {"scope": ["small"], "value": {"equals": true}}}"#
        let json = cards([
            Self.item(Self.card("#FF0000", 200, filler: hideWhenSmall)), Self.item(Self.card("#0000FF", 30)),
        ])
        let state = ThomasState(mutableState: ThomasState.MutableState(), onStateChange: { _ in })
        let (before, after) = try await render(json, constraints: bounded, state: state) {
            state.processSync(outcomes: [ThomasStateAction.setState(.init(key: "small", value: .bool(true), ttl: nil)).asOutcome])
        }

        #expect(Self.heights(before, x: 100, Self.red) == [200])
        #expect(Self.heights(before, x: 300, Self.blue) == [200])
        // The hidden filler takes no room, so both cards drop to the short one's 30.
        #expect(Self.heights(after, x: 300, Self.blue) == [30])
        #expect(Self.heights(after, x: 100, Self.red) == [30])
    }


    // MARK: Review follow-ups

    /// A label card filled `hex`.
    private static func labelCard(_ hex: String) -> String {
        #"""
        {"type": "label", "text": "short",
         "text_appearance": {"font_size": 14, "color": {"default": {"type": "hex", "hex": "#000000", "alpha": 1}}},
         "background_color": {"default": {"type": "hex", "hex": "\#(hex)", "alpha": 1}}}
        """#
    }

    @Test("tallest_row stretches a 100% label card to the tallest card")
    func tallestRowLabelCard() async throws {
        let snapshot = try await render(cards([
            Self.item(Self.labelCard("#FF0000")), Self.item(Self.card("#0000FF", 80)),
        ]), constraints: bounded)

        #expect(Self.heights(snapshot, x: 300, Self.blue) == [80])
        #expect(Self.heights(snapshot, x: 20, Self.red) == [80])
    }

    @Test("a share over 100% stops at its own row")
    func rowShareCapped() async throws {
        let snapshot = try await render(cards([
            Self.item(Self.fill("#FF0000"), height: "40"), Self.item(Self.fill("#0000FF"), height: #""200%""#),
            Self.item(Self.fill("#FFFF00"), height: "40"),
        ], tallest: false), constraints: bounded)

        #expect(Self.heights(snapshot, x: 300, Self.blue) == [40])
        #expect(Self.heights(snapshot, x: 100, Self.yellow) == [40])
    }

    @Test("a container child at start sits at the right edge in RTL")
    func containerStartRTL() async throws {
        let json = #"""
        {"type": "container", "items": [
          {"position": {"horizontal": "start", "vertical": "top"}, "size": {"width": 100, "height": 20}, "view": \#(Self.fill("#FF0000"))}
        ]}
        """#
        let snapshot = try await render(json, constraints: bounded, layoutDirection: .rightToLeft)

        #expect(snapshot.horizontalRuns(y: 10, Self.red).map { [$0.0, $0.1] } == [[300, 100]])
    }

}

#endif
