/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Testing

@testable @_spi(AirshipInternal) import AirshipSceneRenderer

@Suite("Grid layout")
struct GridLayoutTest {
    private typealias Config = ThomasViewInfo.GridLayout.Config

    private func config(_ json: String) throws -> Config {
        try JSONDecoder().decode(Config.self, from: Data(json.utf8))
    }

    private func configs(_ json: String) throws -> ThomasViewInfo.GridLayout.Configs {
        try JSONDecoder().decode(ThomasViewInfo.GridLayout.Configs.self, from: Data(json.utf8))
    }

    @Test("fits as many minimum-width columns as the width allows")
    func fitsColumns() throws {
        let config = try config(#"{"max_columns": 11, "min_column_width": {"type": "fixed", "points": 44}, "column_spacing": 8}"#)
        #expect(GridColumns.columnCount(config, width: 320, textScale: 1) == 6)
    }

    @Test("counts an exact fit and one short by less than the slack")
    func exactFit() throws {
        let config = try config(#"{"max_columns": 10, "min_column_width": {"type": "fixed", "points": 50}, "column_spacing": 10}"#)
        #expect(GridColumns.columnCount(config, width: 170, textScale: 1) == 3)
        #expect(GridColumns.columnCount(config, width: 169.6, textScale: 1) == 3)
        #expect(GridColumns.columnCount(config, width: 169, textScale: 1) == 2)
    }

    @Test("caps at max_columns and never drops below one")
    func bounds() throws {
        let capped = try config(#"{"max_columns": 4, "min_column_width": {"type": "fixed", "points": 20}}"#)
        #expect(GridColumns.columnCount(capped, width: 1000, textScale: 1) == 4)

        let wide = try config(#"{"max_columns": 4, "min_column_width": {"type": "fixed", "points": 200}}"#)
        #expect(GridColumns.columnCount(wide, width: 100, textScale: 1) == 1)

        let zero = try config(#"{"max_columns": 0}"#)
        #expect(GridColumns.columnCount(zero, width: 100, textScale: 1) == 1)
    }

    @Test("draws max_columns without a minimum, a positive minimum, or a width")
    func maxColumnsFallback() throws {
        let noMinimum = try config(#"{"max_columns": 3}"#)
        #expect(GridColumns.columnCount(noMinimum, width: 50, textScale: 1) == 3)

        let zeroMinimum = try config(#"{"max_columns": 3, "min_column_width": {"type": "fixed", "points": 0}}"#)
        #expect(GridColumns.columnCount(zeroMinimum, width: 50, textScale: 1) == 3)

        let unbounded = try config(#"{"max_columns": 3, "min_column_width": {"type": "fixed", "points": 44}}"#)
        #expect(GridColumns.columnCount(unbounded, width: nil, textScale: 1) == 3)
    }

    @Test("scales the minimum by the text size only for text_scaled")
    func textScale() throws {
        let fixed = try config(#"{"max_columns": 11, "min_column_width": {"type": "fixed", "points": 44}, "column_spacing": 8}"#)
        let scaled = try config(#"{"max_columns": 11, "min_column_width": {"type": "text_scaled", "points": 44}, "column_spacing": 8}"#)
        #expect(GridColumns.columnCount(fixed, width: 320, textScale: 2) == 6)
        #expect(GridColumns.columnCount(scaled, width: 320, textScale: 2) == 3)
        #expect(GridColumns.columnCount(scaled, width: 320, textScale: 1) == 6)
    }

    @Test("takes the first matching selector, with inclusive grid_width bounds")
    func selectors() throws {
        let configs = try configs(#"""
        {
          "default": {"max_columns": 1},
          "selectors": [
            {"grid_width": {"at_most": 300}, "config": {"max_columns": 2}},
            {"grid_width": {"at_least": 300}, "config": {"max_columns": 3}},
            {"platform": "android", "config": {"max_columns": 4}}
          ]
        }
        """#)
        func columns(_ width: CGFloat?) -> Double {
            GridColumns.resolveConfig(configs, environment: .init(gridWidth: width)).maxColumns
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
          "default": {"max_columns": 1},
          "selectors": [
            {"platform": "web", "config": {"max_columns": 4}},
            {"window_size": "large", "orientation": "landscape", "config": {"max_columns": 5}},
            {"platform": "ios", "window_size": "small", "config": {"max_columns": 2}}
          ]
        }
        """#)
        func columns(_ windowSize: ThomasWindowSize, _ orientation: ThomasOrientation) -> Double {
            GridColumns.resolveConfig(
                configs,
                environment: .init(windowSize: windowSize, orientation: orientation)
            ).maxColumns
        }
        #expect(columns(.small, .portrait) == 2)
        #expect(columns(.large, .landscape) == 5)
        #expect(columns(.large, .portrait) == 1)
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
              "max_columns": 11,
              "min_column_width": {"type": "text_scaled", "points": 44},
              "column_spacing": 6,
              "row_spacing": 6,
              "partial_row_alignment": "center",
              "row_alignment": "top",
              "cell_aspect_ratio": 1
            },
            "selectors": [{"grid_width": {"at_least": 480}, "config": {"max_columns": 6}}]
          },
          "items": [
            {"column_span": 2, "view": {"type": "empty_view"}},
            {"size": {"width": 50, "height": "auto"}, "position": {"horizontal": "start", "vertical": "top"}, "view": {"type": "empty_view"}}
          ],
          "accessibility_role": {"type": "list_view"}
        }
        """#
        let view = try JSONDecoder().decode(ThomasViewInfo.self, from: Data(json.utf8))
        guard case .gridLayout(let grid) = view else {
            Issue.record("expected a grid layout")
            return
        }
        let properties = grid.properties
        #expect(properties.config.defaultConfig.minColumnWidth?.type == .textScaled)
        #expect(properties.config.defaultConfig.partialRowAlignment == .center)
        #expect(properties.config.selectors?.first?.gridWidth?.atLeast == 480)
        #expect(properties.items[0].columnSpan == 2)
        #expect(properties.items[0].resolvedSize == ThomasSize(width: .percent(100), height: .auto))
        #expect(properties.items[0].resolvedPosition == ThomasPosition(horizontal: .center, vertical: .center))
        #expect(properties.items[1].resolvedPosition == ThomasPosition(horizontal: .start, vertical: .top))
        #expect(properties.accessibilityRole?.type == .listView)
    }

    @Test("a grid supplies its own width only when every config sets a minimum column width")
    func establishesWidthFromMinimum() throws {
        func grid(_ configs: String) throws -> ThomasViewInfo {
            try JSONDecoder().decode(ThomasViewInfo.self, from: Data(#"""
            {"type": "grid_layout", "config": \#(configs),
             "items": [{"size": {"width": "100%", "height": "100%"}, "view": {"type": "empty_view"}}]}
            """#.utf8))
        }
        let minimum = #"{"max_columns": 3, "min_column_width": {"type": "fixed", "points": 80}}"#

        #expect(try grid(#"{"default": \#(minimum)}"#).establishesLength(on: .horizontal))
        #expect(try !grid(#"{"default": {"max_columns": 3}}"#).establishesLength(on: .horizontal))
        #expect(try !grid(#"{"default": \#(minimum), "selectors": [{"grid_width": {"at_most": 200}, "config": {"max_columns": 2}}]}"#)
            .establishesLength(on: .horizontal))
        #expect(try !grid(#"{"default": {"max_columns": 3, "min_column_width": {"type": "fixed", "points": 0}}}"#)
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
