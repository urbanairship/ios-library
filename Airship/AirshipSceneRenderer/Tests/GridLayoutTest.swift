/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Testing

@_spi(AirshipInternal) import AirshipBasement
@testable @_spi(AirshipInternal) import AirshipSceneRenderer

@Suite("Grid layout")
struct GridLayoutTest {
    private final class StubThomasDelegate: ThomasDelegate {
        func onVisibilityChanged(isVisible: Bool, isForegrounded: Bool) {}
        func onReportingEvent(_ event: ThomasReportingEvent) {}
        func onDismissed(cancel: Bool) {}
        func onStateChanged(_ state: AirshipJSON) {}
    }

    private typealias Config = ThomasViewInfo.GridLayout.Config

    private func config(_ json: String) throws -> Config {
        try JSONDecoder().decode(Config.self, from: Data(json.utf8))
    }

    private func configs(_ json: String) throws -> ThomasViewInfo.GridLayout.Configs<Config> {
        try JSONDecoder().decode(ThomasViewInfo.GridLayout.Configs<Config>.self, from: Data(json.utf8))
    }

    private func fit(_ max: Int, minWidth: String, spacing: Int? = nil) -> String {
        let spacingField = spacing.map { #", "column_spacing": {"type": "fixed", "space": \#($0)}"# } ?? ""
        return #"{"columns": {"type": "fit", "max": \#(max), "min_width": \#(minWidth)}\#(spacingField)}"#
    }

    private func fixed(_ count: Int) -> String {
        #"{"columns": {"type": "fixed", "count": \#(count)}}"#
    }

    private static let min44 = #"{"type": "fixed", "size": 44}"#

    @Test("fit draws as many minimum-width columns as the width allows")
    func fitsColumns() throws {
        let config = try config(fit(11, minWidth: Self.min44, spacing: 8))
        #expect(GridColumns.columnCount(config, width: 320, textScale: 1) == 6)
    }

    @Test("fit counts an exact fit and one short by less than the slack")
    func exactFit() throws {
        let config = try config(fit(10, minWidth: #"{"type": "fixed", "size": 50}"#, spacing: 10))
        #expect(GridColumns.columnCount(config, width: 170, textScale: 1) == 3)
        #expect(GridColumns.columnCount(config, width: 169.6, textScale: 1) == 3)
        #expect(GridColumns.columnCount(config, width: 169, textScale: 1) == 2)
    }

    @Test("fit caps at max and never drops below one")
    func fitBounds() throws {
        let capped = try config(fit(4, minWidth: #"{"type": "fixed", "size": 20}"#))
        #expect(GridColumns.columnCount(capped, width: 1000, textScale: 1) == 4)

        let wide = try config(fit(4, minWidth: #"{"type": "fixed", "size": 200}"#))
        #expect(GridColumns.columnCount(wide, width: 100, textScale: 1) == 1)

        let zeroMax = try config(fit(0, minWidth: Self.min44))
        #expect(GridColumns.columnCount(zeroMax, width: 100, textScale: 1) == 1)
    }

    @Test("fit draws max with a minimum of 0 or less, or without a width")
    func fitFallsBackToMax() throws {
        let zeroMinimum = try config(fit(3, minWidth: #"{"type": "fixed", "size": 0}"#))
        #expect(GridColumns.columnCount(zeroMinimum, width: 50, textScale: 1) == 3)
        #expect(GridColumns.minColumnWidth(zeroMinimum, textScale: 1) == nil)

        let unbounded = try config(fit(3, minWidth: Self.min44))
        #expect(GridColumns.columnCount(unbounded, width: nil, textScale: 1) == 3)
        #expect(GridColumns.minColumnWidth(unbounded, textScale: 1) == 44)
    }

    @Test("fit's max_width caps columns, scales with text when asked, and never falls below the minimum")
    func maxColumnWidth() throws {
        let uncapped = try config(fit(11, minWidth: Self.min44))
        #expect(GridColumns.maxColumnWidth(uncapped, textScale: 1) == nil)
        #expect(GridColumns.maxColumnWidth(try config(fixed(4)), textScale: 1) == nil)

        let capped = try config(#"{"columns": {"type": "fit", "max": 11, "min_width": {"type": "fixed", "size": 44}, "max_width": {"type": "fixed", "size": 64}}}"#)
        #expect(GridColumns.maxColumnWidth(capped, textScale: 1) == 64)

        let scaled = try config(#"{"columns": {"type": "fit", "max": 11, "min_width": {"type": "fixed", "size": 44}, "max_width": {"type": "text_scaled", "size": 64}}}"#)
        #expect(GridColumns.maxColumnWidth(scaled, textScale: 1.5) == 96)

        let belowMinimum = try config(#"{"columns": {"type": "fit", "max": 11, "min_width": {"type": "fixed", "size": 44}, "max_width": {"type": "fixed", "size": 30}}}"#)
        #expect(GridColumns.maxColumnWidth(belowMinimum, textScale: 1) == 44)
    }

    private func spacing(_ json: String) throws -> ThomasViewInfo.GridLayout.Spacing {
        try JSONDecoder().decode(ThomasViewInfo.GridLayout.Spacing.self, from: Data(json.utf8))
    }

    @Test("spread shares the leftover between the gaps, within the bounds")
    func spreadSpace() throws {
        let open = try spacing(#"{"type": "spread", "min_space": 6}"#)
        let capped = try spacing(#"{"type": "spread", "min_space": 6, "max_space": 20}"#)
        #expect(GridColumns.spreadSpace(open, leftover: 84, count: 4) == 28)
        #expect(GridColumns.spreadSpace(capped, leftover: 84, count: 4) == 20)
        #expect(GridColumns.spreadSpace(capped, leftover: 6, count: 4) == 6)

        let maxBelowMin = try spacing(#"{"type": "spread", "min_space": 10, "max_space": 4}"#)
        #expect(GridColumns.spreadSpace(maxBelowMin, leftover: 84, count: 4) == 10)

        #expect(GridColumns.spreadSpace(try spacing(#"{"type": "fixed", "space": 8}"#), leftover: 84, count: 4) == nil)
        #expect(GridColumns.spreadSpace(open, leftover: 84, count: 1) == nil)
        #expect(GridColumns.spreadSpace(nil, leftover: 84, count: 4) == nil)
    }

    @Test("the column count and a column's share use the minimum space, and spread only widens capped columns' gaps")
    func spreadColumns() throws {
        let config = try config(#"{"columns": {"type": "fit", "max": 4, "min_width": {"type": "fixed", "size": 44}, "max_width": {"type": "fixed", "size": 64}}, "column_spacing": {"type": "spread", "min_space": 6}}"#)
        #expect(GridColumns.columnCount(config, width: 340, textScale: 1) == 4)
        #expect(GridColumns.minSpace(config.columnSpacing) == 6)

        func metrics(width: CGFloat) -> GridMetrics {
            GridMetrics(
                columns: 4,
                columnSpacing: config.columnSpacing,
                rowSpacing: nil,
                contentPosition: GridMetrics.defaultContentPosition,
                sizing: .divides(width),
                maxColumnWidth: GridColumns.maxColumnWidth(config, textScale: 1),
                fillsOffer: false,
                aspectRatio: nil,
                placements: [],
                rowHasBasis: [],
                hasPercentHeights: false,
                readingRank: []
            )
        }
        // Capped at 64, the 84 left over in 340 goes into 3 gaps of 28.
        #expect(metrics(width: 340).columns(dividing: 340) == (64, 28))
        // Still growing at 250, the columns take the room and the gap stays at its minimum.
        #expect(metrics(width: 250).columns(dividing: 250) == (58, 6))
    }

    @MainActor
    @Test("a scene's shuffled order is derived from its seed, so it is the same every time")
    func sceneShuffledOrder() {
        let environment = ThomasEnvironment(delegate: StubThomasDelegate(), extensions: TestThomasExtensions())
        let first = environment.shuffledOrder(count: 6, page: "page-1", identifier: nil)
        #expect(Set(first) == Set(0..<6))
        #expect(environment.shuffledOrder(count: 6, page: "page-1", identifier: nil) == first)
        #expect(Set(environment.shuffledOrder(count: 3, page: "page-1", identifier: nil)) == Set(0..<3))

        // An identifier tells layouts on one page apart: across a few, the orders don't all match.
        let identified = (0..<8).map { environment.shuffledOrder(count: 6, page: "page-1", identifier: "grid-\($0)") }
        #expect(identified.contains { $0 != first })
        #expect(environment.shuffledOrder(count: 6, page: "page-1", identifier: "grid-3") == identified[3])

        // A new scene gets a new seed: across a few scenes the order doesn't stay fixed.
        let others = (0..<8).map { _ in
            ThomasEnvironment(delegate: StubThomasDelegate(), extensions: TestThomasExtensions())
                .shuffledOrder(count: 6, page: "page-1", identifier: nil)
        }
        #expect(others.contains { $0 != first })
    }

    @Test("items place by order, keeping list or shuffled order among equal ones")
    func placementOrder() {
        // An item at order 1 goes last, one at -1 first; the rest keep their places.
        #expect(GridColumns.placementOrder([0, 1, 2, 3], orders: [1, nil, -1, 0]) == [2, 1, 3, 0])
        // After a shuffle, a "None of these" at order 1 still comes last.
        #expect(GridColumns.placementOrder([2, 4, 0, 1, 3], orders: [nil, nil, nil, nil, 1]) == [2, 0, 1, 3, 4])
    }

    @Test("fixed is always its count, at least one, and has no minimum width")
    func fixedCount() throws {
        let twelve = try config(fixed(12))
        #expect(GridColumns.columnCount(twelve, width: 50, textScale: 1) == 12)
        #expect(GridColumns.columnCount(twelve, width: nil, textScale: 1) == 12)
        #expect(GridColumns.minColumnWidth(twelve, textScale: 1) == nil)

        let zero = try config(fixed(0))
        #expect(GridColumns.columnCount(zero, width: 100, textScale: 1) == 1)
    }

    @Test("fit scales the minimum by the text size only for text_scaled")
    func textScale() throws {
        let unscaled = try config(fit(11, minWidth: Self.min44, spacing: 8))
        let scaled = try config(fit(11, minWidth: #"{"type": "text_scaled", "size": 44}"#, spacing: 8))
        #expect(GridColumns.columnCount(unscaled, width: 320, textScale: 2) == 6)
        #expect(GridColumns.columnCount(scaled, width: 320, textScale: 2) == 3)
        #expect(GridColumns.columnCount(scaled, width: 320, textScale: 1) == 6)
    }

    @Test("takes the first matching selector, with inclusive grid_width bounds")
    func selectors() throws {
        let configs = try configs(#"""
        {
          "default": \#(fixed(1)),
          "selectors": [
            {"grid_width": {"at_most": 300}, "config": \#(fixed(2))},
            {"grid_width": {"at_least": 300}, "config": \#(fixed(3))},
            {"platform": "android", "config": \#(fixed(4))}
          ]
        }
        """#)
        func columns(_ width: CGFloat?) -> Int {
            GridColumns.columnCount(
                GridColumns.resolveConfig(configs, environment: .init(gridWidth: width)),
                width: width,
                textScale: 1
            )
        }
        #expect(columns(250) == 2)
        #expect(columns(300) == 2)
        #expect(columns(301) == 3)
        #expect(columns(nil) == 1)
    }

    @Test("matches platform, window size and orientation")
    func environmentSelectors() throws {
        let configs = try configs(#"""
        {
          "default": \#(fixed(1)),
          "selectors": [
            {"platform": "web", "config": \#(fixed(4))},
            {"window_size": "large", "orientation": "landscape", "config": \#(fixed(5))},
            {"platform": "ios", "window_size": "small", "config": \#(fixed(2))}
          ]
        }
        """#)
        func columns(_ windowSize: ThomasWindowSize, _ orientation: ThomasOrientation) -> Int {
            GridColumns.columnCount(
                GridColumns.resolveConfig(
                    configs,
                    environment: .init(windowSize: windowSize, orientation: orientation)
                ),
                width: 300,
                textScale: 1
            )
        }
        #expect(columns(.small, .portrait) == 2)
        #expect(columns(.large, .landscape) == 5)
        #expect(columns(.large, .portrait) == 1)
    }

    @Test("an item config resolves its span by the grid's selectors and width")
    func itemSelectors() throws {
        let item = try JSONDecoder().decode(
            ThomasViewInfo.GridLayout.Configs<ThomasViewInfo.GridLayout.ItemConfig>.self,
            from: Data(#"""
            {
              "default": {"column_span": 6},
              "selectors": [{"grid_width": {"at_most": 400}, "config": {"column_span": 12}}]
            }
            """#.utf8)
        )
        func span(_ width: CGFloat?) -> Double? {
            GridColumns.resolveConfig(item, environment: .init(gridWidth: width)).columnSpan
        }
        #expect(span(600) == 6)
        #expect(span(400) == 12)
        #expect(span(250) == 12)
        #expect(span(nil) == 6)
    }

    @Test("a 12-column grid lays halves and thirds out by width")
    func twelveColumnSpans() throws {
        let halvesToFull = try JSONDecoder().decode(
            ThomasViewInfo.GridLayout.Configs<ThomasViewInfo.GridLayout.ItemConfig>.self,
            from: Data(#"{"default": {"column_span": 6}, "selectors": [{"grid_width": {"at_most": 300}, "config": {"column_span": 12}}]}"#.utf8)
        )
        let third = try JSONDecoder().decode(
            ThomasViewInfo.GridLayout.Configs<ThomasViewInfo.GridLayout.ItemConfig>.self,
            from: Data(#"{"default": {"column_span": 4}}"#.utf8)
        )
        func rows(at width: CGFloat) -> [Int] {
            let environment = GridColumns.Environment(gridWidth: width)
            let spans = [halvesToFull, halvesToFull, third, third, third].map {
                GridColumns.resolveConfig($0, environment: environment).columnSpan
            }
            return GridColumns.place(spans: spans, columns: 12, alignment: .start).map(\.row)
        }
        #expect(rows(at: 360) == [0, 0, 1, 1, 1])
        #expect(rows(at: 250) == [0, 1, 2, 2, 2])
    }

    @Test("fills rows in order without backfilling, offsetting short rows by half-columns")
    func placement() {
        let start = GridColumns.place(spans: [2, 2, 1], columns: 3, alignment: .start)
        #expect(start == [
            .init(row: 0, halfColumn: 0, span: 2),
            .init(row: 1, halfColumn: 0, span: 2),
            .init(row: 1, halfColumn: 4, span: 1),
        ])

        let center = GridColumns.place(spans: [nil, nil, nil, nil], columns: 3, alignment: .center)
        #expect(center.last == .init(row: 1, halfColumn: 2, span: 1))

        let end = GridColumns.place(spans: [1], columns: 3, alignment: .end)
        #expect(end == [.init(row: 0, halfColumn: 4, span: 1)])
    }

    @Test("clamps spans to between one and the column count")
    func spanClamping() {
        let placements = GridColumns.place(spans: [5, 0, 1.7], columns: 3, alignment: .start)
        #expect(placements.map(\.span) == [3, 1, 1])
        #expect(placements.map(\.row) == [0, 1, 1])
    }

    @Test("decodes a grid_layout view")
    func decoding() throws {
        let json = #"""
        {
          "type": "grid_layout",
          "config": {
            "default": {
              "columns": {"type": "fit", "max": 11, "min_width": {"type": "text_scaled", "size": 44}, "max_width": {"type": "fixed", "size": 64}},
              "column_spacing": {"type": "fixed", "space": 6},
              "row_spacing": {"type": "fixed", "space": 6},
              "partial_row_position": "center",
              "content_position": {"horizontal": "center", "vertical": "bottom"},
              "cell_aspect_ratio": 1
            },
            "selectors": [{"grid_width": {"at_least": 480}, "config": {"columns": {"type": "fixed", "count": 6}}}]
          },
          "items": [
            {"config": {"default": {"column_span": 2}, "selectors": [{"platform": "ios", "config": {"column_span": 3}}]}, "view": {"type": "empty_view"}},
            {"size": {"width": 50, "height": "auto"}, "position": {"horizontal": "start", "vertical": "top"}, "view": {"type": "empty_view"}}
          ],
          "header": {"size": {"width": "100%", "height": "auto"}, "position": {"horizontal": "start", "vertical": "center"}, "view": {"type": "empty_view"}},
          "footer": {"view": {"type": "empty_view"}},
          "randomize_children": true,
          "accessibility_role": {"type": "list_view"}
        }
        """#
        let view = try JSONDecoder().decode(ThomasViewInfo.self, from: Data(json.utf8))
        guard case .gridLayout(let grid) = view else {
            Issue.record("expected a grid layout")
            return
        }
        let properties = grid.properties
        #expect(properties.config.defaultConfig.columns == .fit(
            max: 11,
            minWidth: .init(type: .textScaled, size: 44),
            maxWidth: .init(type: .fixed, size: 64)
        ))
        #expect(properties.config.defaultConfig.contentPosition == ThomasPosition(horizontal: .center, vertical: .bottom))
        #expect(properties.config.selectors?.first?.config.columns == .fixed(count: 6))
        #expect(properties.config.defaultConfig.partialRowPosition == .center)
        #expect(properties.config.selectors?.first?.gridWidth?.atLeast == 480)
        #expect(properties.items[0].config?.defaultConfig.columnSpan == 2)
        #expect(properties.items[0].config?.selectors?.first?.config.columnSpan == 3)
        #expect(properties.items[1].config == nil)
        #expect(properties.items[0].resolvedSize == ThomasSize(width: .percent(100), height: .auto))
        #expect(properties.items[0].resolvedPosition == ThomasPosition(horizontal: .center, vertical: .center))
        #expect(properties.items[1].resolvedPosition == ThomasPosition(horizontal: .start, vertical: .top))
        #expect(properties.accessibilityRole?.type == .listView)
        #expect(properties.randomizeChildren == true)
        #expect(properties.config.defaultConfig.columnSpacing == .fixed(space: 6))
        #expect(properties.header?.resolvedPosition == ThomasPosition(horizontal: .start, vertical: .center))
        #expect(properties.footer?.resolvedSize == ThomasSize(width: .percent(100), height: .auto))
        #expect(view.immediateChildren?.count == 4)
    }

    @Test("a grid supplies its own width only when every config is fit with a minimum")
    func establishesWidthFromMinimum() throws {
        func grid(_ configs: String) throws -> ThomasViewInfo {
            try JSONDecoder().decode(ThomasViewInfo.self, from: Data(#"""
            {"type": "grid_layout", "config": \#(configs),
             "items": [{"size": {"width": "100%", "height": "100%"}, "view": {"type": "empty_view"}}]}
            """#.utf8))
        }
        let minimum = #"{"columns": {"type": "fit", "max": 3, "min_width": {"type": "fixed", "size": 80}}}"#

        #expect(try grid(#"{"default": \#(minimum)}"#).establishesLength(on: .horizontal))
        #expect(try !grid(#"{"default": {"columns": {"type": "fixed", "count": 3}}}"#).establishesLength(on: .horizontal))
        #expect(try !grid(#"{"default": \#(minimum), "selectors": [{"grid_width": {"at_most": 200}, "config": {"columns": {"type": "fixed", "count": 2}}}]}"#)
            .establishesLength(on: .horizontal))
        #expect(try !grid(#"{"default": {"columns": {"type": "fit", "max": 3, "min_width": {"type": "fixed", "size": 0}}}}"#)
            .establishesLength(on: .horizontal))
        // A minimum says nothing about the grid's height; the items here take a share of theirs.
        #expect(try !grid(#"{"default": \#(minimum)}"#).establishesLength(on: .vertical))
    }

    @Test("an auto child of a horizontal scroll's content carries the scrolling axis until a length is declared")
    func scrollingAxes() {
        var content = ViewConstraints(width: 300, maxWidth: nil)
        content.scrollingAxes = .horizontal

        let auto = content.childConstraints(ThomasSize(width: .auto, height: .auto), margin: nil)
        #expect(auto.scrollingAxes.contains(.horizontal))

        let percent = content.childConstraints(ThomasSize(width: .percent(50), height: .auto), margin: nil)
        #expect(percent.width == 150)
        #expect(!percent.scrollingAxes.contains(.horizontal))
    }
}
