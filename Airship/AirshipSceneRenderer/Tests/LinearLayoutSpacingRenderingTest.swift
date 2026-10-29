/* Copyright Airship and Contributors */

#if !os(macOS) && !os(watchOS) && !os(tvOS)

import Foundation
import Combine
import SwiftUI
import Testing
import UIKit

@_spi(AirshipInternal) import AirshipBasement
@testable @_spi(AirshipInternal) import AirshipSceneRenderer

/// Renders real linear layouts in a window and reads item extents off the pixels, pinning the
/// geometry web and Android draw for the same `spacing`.
@MainActor
@Suite("Linear layout spacing")
struct LinearLayoutSpacingRenderingTest {

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
        func verticalRuns(x: Int, _ color: (Int, Int, Int)) -> [Run] {
            runs((0..<height).map { isColor(x, $0, color) })
        }

        /// The runs of `color` along row `y`, as (start, length).
        func horizontalRuns(y: Int, _ color: (Int, Int, Int)) -> [Run] {
            runs((0..<width).map { isColor($0, y, color) })
        }

        private func runs(_ flags: [Bool]) -> [Run] {
            var result: [Run] = []
            var start: Int?
            for (index, flag) in (flags + [false]).enumerated() {
                if flag, start == nil { start = index }
                if !flag, let begin = start {
                    result.append(Run(start: begin, length: index - begin))
                    start = nil
                }
            }
            return result
        }
    }

    private struct Run: Equatable {
        let start: Int
        let length: Int
    }

    private static let red = (255, 0, 0)
    private static let blue = (0, 0, 255)
    private static let green = (0, 255, 0)

    private static let hiddenForGood = #"{"default": false, "invert_when_state_matches": {"key": "never_set", "value": {"equals": true}}}"#

    private static func fill(_ hex: String, hidden: Bool = false) -> String {
        let visibility = hidden ? #", "visibility": \#(hiddenForGood)"# : ""
        return #"{"type": "empty_view", "background_color": {"default": {"type": "hex", "hex": "\#(hex)", "alpha": 1}}\#(visibility)}"#
    }

    private static let colors = ["#FF0000", "#0000FF", "#00FF00"]

    /// An item of `size` filled with the i-th of red, blue, green.
    private static func item(
        _ index: Int,
        width: String = "\"100%\"",
        height: String,
        margin: String? = nil,
        order: Int? = nil,
        hidden: Bool = false
    ) -> String {
        let margin = margin.map { #", "margin": \#($0)"# } ?? ""
        let config = order.map { #", "config": {"order": \#($0)}"# } ?? ""
        return #"{"size": {"width": \#(width), "height": \#(height)}\#(margin)\#(config), "view": \#(fill(colors[index], hidden: hidden))}"#
    }

    /// A stack of `items` with `spacing`, in an item of `size` at the window's top-leading corner.
    private func stack(
        _ direction: String,
        spacing: String? = nil,
        items: [String],
        width: String = "\"100%\"",
        height: String = "\"auto\""
    ) -> String {
        let spacing = spacing.map { #", "spacing": \#($0)"# } ?? ""
        return #"""
        {"type": "linear_layout", "direction": "vertical", "items": [{
          "size": {"width": \#(width), "height": \#(height)},
          "position": {"horizontal": "start", "vertical": "top"},
          "view": {"type": "linear_layout", "direction": "\#(direction)"\#(spacing), "items": [\#(items.joined(separator: ","))]}
        }]}
        """#
    }

    private func render(_ json: String) async throws -> Snapshot {
        let view = try JSONDecoder().decode(ThomasViewInfo.self, from: Data(json.utf8))
        let constraints = ViewConstraints(width: Self.size.width, height: Self.size.height)
        let content = thomasEnvironment.viewFactory.createView(view, constraints: constraints)
            .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
            .background(Color.white)
            .environmentObject(thomasEnvironment)
            .environmentObject(thomasState)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        // Each render is one layout pass; measurements land on the main queue between them.
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

    private func column(_ snapshot: Snapshot) -> [Run] {
        (0..<3).compactMap { snapshot.verticalRuns(x: 10, Self.colorValues[$0]).first }
    }

    private func row(_ snapshot: Snapshot) -> [Run] {
        (0..<3).compactMap { snapshot.horizontalRuns(y: 10, Self.colorValues[$0]).first }
    }

    private static let colorValues = [red, blue, green]

    @Test("a column puts spacing between its items and nowhere else")
    func column() async throws {
        let snapshot = try await render(stack("vertical", spacing: "12", items: (0..<3).map { Self.item($0, height: "40") }))
        #expect(column(snapshot) == [Run(start: 0, length: 40), Run(start: 52, length: 40), Run(start: 104, length: 40)])
    }

    @Test("a row puts spacing between its items")
    func row() async throws {
        let snapshot = try await render(stack("horizontal", spacing: "12", items: (0..<3).map { Self.item($0, width: "60", height: "40") }, height: "40"))
        #expect(row(snapshot) == [Run(start: 0, length: 60), Run(start: 72, length: 60), Run(start: 144, length: 60)])
    }

    @Test("spacing adds to a column's item margins")
    func columnMargins() async throws {
        let margin = #"{"top": 4, "bottom": 4}"#
        let snapshot = try await render(stack("vertical", spacing: "12", items: (0..<3).map { Self.item($0, height: "40", margin: margin) }))
        #expect(column(snapshot) == [Run(start: 4, length: 40), Run(start: 64, length: 40), Run(start: 124, length: 40)])
    }

    @Test("spacing adds to a row's item margins")
    func rowMargins() async throws {
        let margin = #"{"start": 4, "end": 4}"#
        let snapshot = try await render(stack("horizontal", spacing: "12", items: (0..<3).map { Self.item($0, width: "60", height: "40", margin: margin) }, height: "40"))
        #expect(row(snapshot) == [Run(start: 4, length: 60), Run(start: 84, length: 60), Run(start: 164, length: 60)])
    }

    @Test("two 50% items in a 200-high column share what the spacing leaves")
    func oversubscribedColumn() async throws {
        let snapshot = try await render(stack("vertical", spacing: "20", items: [
            Self.item(0, height: "\"50%\""), Self.item(1, height: "\"50%\"")
        ], height: "200"))
        #expect(column(snapshot).prefix(2) == [Run(start: 0, length: 90), Run(start: 110, length: 90)])
    }

    @Test("a 25% item beside points keeps its whole share when everything fits")
    func percentBesidePoints() async throws {
        let snapshot = try await render(stack("vertical", spacing: "10", items: [
            Self.item(0, height: "\"25%\""), Self.item(1, height: "60")
        ], height: "200"))
        #expect(column(snapshot).prefix(2) == [Run(start: 0, length: 50), Run(start: 60, length: 60)])
    }

    @Test("a row's 50% beside points keeps its share")
    func rowPercentBesidePoints() async throws {
        let snapshot = try await render(stack("horizontal", spacing: "16", items: [
            Self.item(0, width: "\"50%\"", height: "40"), Self.item(1, width: "100", height: "40")
        ], width: "300", height: "40"))
        #expect(row(snapshot).prefix(2) == [Run(start: 0, length: 150), Run(start: 166, length: 100)])
    }

    @Test("a hugging column counts its spacing as fixed when solving its percentages")
    func hugsWithPercent() async throws {
        let snapshot = try await render(stack("vertical", spacing: "10", items: [
            Self.item(0, height: "\"50%\""), Self.item(1, height: "60")
        ]))
        #expect(column(snapshot).prefix(2) == [Run(start: 0, length: 70), Run(start: 80, length: 60)])
    }

    @Test("a hidden item in the middle leaves no gap")
    func hiddenMiddle() async throws {
        let snapshot = try await render(stack("vertical", spacing: "12", items: [
            Self.item(0, height: "40"), Self.item(1, height: "40", hidden: true), Self.item(2, height: "40")
        ]))
        #expect(snapshot.verticalRuns(x: 10, Self.red) == [Run(start: 0, length: 40)])
        #expect(snapshot.verticalRuns(x: 10, Self.green) == [Run(start: 52, length: 40)])
    }

    @Test("a hidden first item leaves no leading gap")
    func hiddenFirst() async throws {
        let snapshot = try await render(stack("vertical", spacing: "12", items: [
            Self.item(0, height: "40", hidden: true), Self.item(1, height: "40"), Self.item(2, height: "40")
        ]))
        #expect(snapshot.verticalRuns(x: 10, Self.blue) == [Run(start: 0, length: 40)])
        #expect(snapshot.verticalRuns(x: 10, Self.green) == [Run(start: 52, length: 40)])
    }

    @Test("a hidden last item leaves no trailing gap")
    func hiddenLast() async throws {
        let snapshot = try await render(stack("vertical", spacing: "12", items: [
            Self.item(0, height: "40"), Self.item(1, height: "40"), Self.item(2, height: "40", hidden: true)
        ]))
        #expect(snapshot.verticalRuns(x: 10, Self.red) == [Run(start: 0, length: 40)])
        #expect(snapshot.verticalRuns(x: 10, Self.blue) == [Run(start: 52, length: 40)])
    }

    @Test("a hidden item keeps its margins out of the layout too")
    func hiddenWithMargins() async throws {
        let margin = #"{"top": 6, "bottom": 6}"#
        let snapshot = try await render(stack("vertical", spacing: "12", items: [
            Self.item(0, height: "40"), Self.item(1, height: "40", margin: margin, hidden: true), Self.item(2, height: "40")
        ]))
        #expect(snapshot.verticalRuns(x: 10, Self.green) == [Run(start: 52, length: 40)])
    }

    @Test("gaps come between neighbours as drawn after ordering")
    func order() async throws {
        let snapshot = try await render(stack("vertical", spacing: "12", items: [
            Self.item(0, height: "40", order: 3), Self.item(1, height: "40", order: 2), Self.item(2, height: "40", order: 1)
        ]))
        #expect(snapshot.verticalRuns(x: 10, Self.green) == [Run(start: 0, length: 40)])
        #expect(snapshot.verticalRuns(x: 10, Self.blue) == [Run(start: 52, length: 40)])
        #expect(snapshot.verticalRuns(x: 10, Self.red) == [Run(start: 104, length: 40)])
    }

    @Test("omitted, zero and negative spacing draw flush", arguments: [nil, "0", "-8"])
    func flush(spacing: String?) async throws {
        let snapshot = try await render(stack("vertical", spacing: spacing, items: [
            Self.item(0, height: "40"), Self.item(1, height: "40")
        ]))
        #expect(column(snapshot).prefix(2) == [Run(start: 0, length: 40), Run(start: 40, length: 40)])
    }
}

#endif
