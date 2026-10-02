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
        let first = environment.shuffledOrder(count: 6, identifier: nil)
        #expect(Set(first) == Set(0..<6))
        #expect(environment.shuffledOrder(count: 6, identifier: nil) == first)

        // A new scene gets a new seed: across a few scenes the order doesn't stay fixed.
        let others = (0..<8).map { _ in
            ThomasEnvironment(delegate: StubThomasDelegate(), extensions: TestThomasExtensions())
                .shuffledOrder(count: 6, identifier: nil)
        }
        #expect(others.contains { $0 != first })
    }

    @MainActor
    @Test("a host's random seed fixes every shuffled order")
    func hostSeededShuffledOrder() {
        let environment = ThomasEnvironment(
            delegate: StubThomasDelegate(),
            extensions: TestThomasExtensions(randomSeed: SeededShuffle.uiTestSeed)
        )
        #expect(environment.shuffledOrder(count: 5, identifier: "survey_options") == [0, 4, 3, 2, 1])
        #expect(environment.shuffledOrder(count: 5, identifier: nil) == [1, 3, 2, 0, 4])
    }

    @Test("items place by order, keeping list or shuffled order among equal ones")
    func placementOrder() {
        // An item at order 1 goes last, one at -1 first; the rest keep their places.
        #expect(ItemOrder.sorted([0, 1, 2, 3], orders: [1, nil, -1, 0]) == [2, 1, 3, 0])
        // After a shuffle, a "None of these" at order 1 still comes last.
        #expect(ItemOrder.sorted([2, 4, 0, 1, 3], orders: [nil, nil, nil, nil, 1]) == [2, 0, 1, 3, 4])
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

    private static func gridWidth(_ range: String) -> String {
        #"{"scope": ["$grids", "current", "width"], "value": \#(range)}"#
    }

    @MainActor
    private func gridScopedState(_ state: AirshipJSON = [:], width: CGFloat?) -> ThomasState {
        ThomasState(
            mutableState: ThomasState.MutableState(initialState: state),
            gridState: ThomasGridState(width: width),
            onStateChange: { _ in }
        )
    }

    @MainActor
    private func gridConfig(
        _ grid: ThomasViewInfo.GridLayout,
        state: AirshipJSON = [:],
        width: CGFloat?
    ) -> Config {
        ThomasPropertyOverride.resolveRequired(
            state: gridScopedState(state, width: width),
            overrides: grid.overrides?.config,
            defaultValue: grid.properties.config
        )
    }

    @MainActor
    private func itemSpans(_ grid: ThomasViewInfo.GridLayout, width: CGFloat?) -> [Double?] {
        let state = gridScopedState(width: width)
        return grid.properties.items.map { item in
            ThomasPropertyOverride.resolveOptional(
                state: state,
                overrides: item.overrides?.config,
                defaultValue: item.config
            )?.columnSpan
        }
    }

    private func gridInfo(_ json: String) throws -> ThomasViewInfo.GridLayout {
        let view = try JSONDecoder().decode(ThomasViewInfo.self, from: Data(json.utf8))
        guard case .gridLayout(let grid) = view else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "expected a grid layout"))
        }
        return grid
    }

    @MainActor
    @Test("takes the first matching config override, with inclusive $grids.current.width bounds")
    func configOverrides() throws {
        let grid = try gridInfo(#"""
        {
          "type": "grid_layout", "identifier": "grid-1",
          "config": \#(fixed(1)),
          "view_overrides": {
            "config": [
              {"when_state_matches": \#(Self.gridWidth(#"{"at_most": 300}"#)), "value": \#(fixed(2))},
              {"when_state_matches": \#(Self.gridWidth(#"{"at_least": 300}"#)), "value": \#(fixed(3))}
            ]
          },
          "items": []
        }
        """#)
        func columns(_ width: CGFloat?) -> Int {
            GridColumns.columnCount(gridConfig(grid, width: width), width: width, textScale: 1)
        }
        #expect(columns(250) == 2)
        #expect(columns(300) == 2)
        #expect(columns(301) == 3)
        #expect(columns(nil) == 1)
    }

    @MainActor
    @Test("config overrides match the scene state alongside $grids")
    func configOverridesMatchState() throws {
        let grid = try gridInfo(#"""
        {
          "type": "grid_layout", "identifier": "grid-2",
          "config": \#(fixed(1)),
          "view_overrides": {
            "config": [
              {"when_state_matches": {"key": "layout", "value": {"equals": "wide"}}, "value": \#(fixed(5))}
            ]
          },
          "items": []
        }
        """#)
        #expect(GridColumns.columnCount(gridConfig(grid, state: ["layout": "wide"], width: 300), width: 300, textScale: 1) == 5)
        #expect(GridColumns.columnCount(gridConfig(grid, state: ["layout": "narrow"], width: 300), width: 300, textScale: 1) == 1)
    }

    @MainActor
    @Test("$grids follows the grid's width, leaves width out when unbounded, and stays out of the parent state")
    func gridsState() {
        let parent = ThomasState(mutableState: ThomasState.MutableState(), onStateChange: { _ in })
        let gridState = ThomasGridState(width: nil)
        let scoped = parent.with(gridState: gridState)
        #expect(scoped.state.object?["$grids"] == ["current": [:]])

        gridState.width = 320
        #expect(scoped.state.object?["$grids"] == ["current": ["width": 320]])
        #expect(parent.state.object?["$grids"] == nil)
    }

    @MainActor
    @Test("an item override resolves its span by the grid's width")
    func itemOverrides() throws {
        let grid = try gridInfo(#"""
        {
          "type": "grid_layout", "identifier": "grid-3",
          "config": \#(fixed(12)),
          "items": [
            {
              "config": {"column_span": 6},
              "overrides": {"config": [{"when_state_matches": \#(Self.gridWidth(#"{"at_most": 400}"#)), "value": {"column_span": 12}}]},
              "view": {"type": "empty_view"}
            }
          ]
        }
        """#)
        #expect(itemSpans(grid, width: 600) == [6])
        #expect(itemSpans(grid, width: 400) == [12])
        #expect(itemSpans(grid, width: 250) == [12])
        #expect(itemSpans(grid, width: nil) == [6])
    }

    @MainActor
    @Test("a 12-column grid lays halves and thirds out by width")
    func twelveColumnSpans() throws {
        let half = #"""
        {
          "config": {"column_span": 6},
          "overrides": {"config": [{"when_state_matches": \#(Self.gridWidth(#"{"at_most": 300}"#)), "value": {"column_span": 12}}]},
          "view": {"type": "empty_view"}
        }
        """#
        let third = #"{"config": {"column_span": 4}, "view": {"type": "empty_view"}}"#
        let grid = try gridInfo(#"""
        {"type": "grid_layout", "identifier": "grid-4", "config": \#(fixed(12)), "items": [\#(half), \#(half), \#(third), \#(third), \#(third)]}
        """#)
        func rows(at width: CGFloat) -> [Int] {
            GridColumns.place(spans: itemSpans(grid, width: width), columns: 12, alignment: .start).map(\.row)
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

    @MainActor
    @Test("decodes a grid_layout view")
    func decoding() throws {
        let json = #"""
        {
          "type": "grid_layout", "identifier": "grid-5",
          "config": {
            "columns": {"type": "fit", "max": 11, "min_width": {"type": "text_scaled", "size": 44}, "max_width": {"type": "fixed", "size": 64}},
            "column_spacing": {"type": "fixed", "space": 6},
            "row_spacing": {"type": "fixed", "space": 6},
            "partial_row_position": "center",
            "content_position": {"horizontal": "center", "vertical": "bottom"},
            "cell_aspect_ratio": 1
          },
          "view_overrides": {
            "config": [{"when_state_matches": \#(Self.gridWidth(#"{"at_least": 480}"#)), "value": {"columns": {"type": "fixed", "count": 6}}}]
          },
          "items": [
            {"config": {"column_span": 2}, "overrides": {"config": [{"value": {"column_span": 3}}]}, "view": {"type": "empty_view"}},
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
        #expect(properties.config.columns == .fit(
            max: 11,
            minWidth: .init(type: .textScaled, size: 44),
            maxWidth: .init(type: .fixed, size: 64)
        ))
        #expect(properties.identifier == "grid-5")
        #expect(properties.config.contentPosition == ThomasPosition(horizontal: .center, vertical: .bottom))
        #expect(properties.config.partialRowPosition == .center)
        #expect(grid.overrides?.config?.first?.value?.columns == .fixed(count: 6))
        #expect(gridConfig(grid, width: 480).columns == .fixed(count: 6))
        #expect(gridConfig(grid, width: 479).columns == properties.config.columns)
        #expect(properties.items[0].config?.columnSpan == 2)
        #expect(properties.items[0].overrides?.config?.first?.value?.columnSpan == 3)
        #expect(properties.items[1].config == nil)
        #expect(properties.items[1].overrides == nil)
        #expect(properties.items[0].resolvedSize == ThomasSize(width: .percent(100), height: .auto))
        #expect(properties.items[0].resolvedPosition == ThomasPosition(horizontal: .center, vertical: .center))
        #expect(properties.items[1].resolvedPosition == ThomasPosition(horizontal: .start, vertical: .top))
        #expect(properties.accessibilityRole?.type == .listView)
        #expect(properties.randomizeChildren == true)
        #expect(properties.config.columnSpacing == .fixed(space: 6))
        #expect(properties.header?.resolvedPosition == ThomasPosition(horizontal: .start, vertical: .center))
        #expect(properties.footer?.resolvedSize == ThomasSize(width: .percent(100), height: .auto))
        #expect(view.immediateChildren?.count == 4)
    }

    @Test("a grid supplies its own width only when every config is fit with a minimum")
    func establishesWidthFromMinimum() throws {
        func grid(_ config: String, overrides: String? = nil) throws -> ThomasViewInfo {
            let viewOverrides = overrides.map { #", "view_overrides": {"config": \#($0)}"# } ?? ""
            return try JSONDecoder().decode(ThomasViewInfo.self, from: Data(#"""
            {"type": "grid_layout", "identifier": "grid-6", "config": \#(config)\#(viewOverrides),
             "items": [{"size": {"width": "100%", "height": "100%"}, "view": {"type": "empty_view"}}]}
            """#.utf8))
        }
        let minimum = #"{"columns": {"type": "fit", "max": 3, "min_width": {"type": "fixed", "size": 80}}}"#
        let narrowFixed = #"[{"when_state_matches": \#(Self.gridWidth(#"{"at_most": 200}"#)), "value": {"columns": {"type": "fixed", "count": 2}}}]"#

        #expect(try grid(minimum).establishesLength(on: .horizontal))
        #expect(try !grid(#"{"columns": {"type": "fixed", "count": 3}}"#).establishesLength(on: .horizontal))
        #expect(try !grid(minimum, overrides: narrowFixed).establishesLength(on: .horizontal))
        #expect(try !grid(#"{"columns": {"type": "fit", "max": 3, "min_width": {"type": "fixed", "size": 0}}}"#)
            .establishesLength(on: .horizontal))
        // A minimum says nothing about the grid's height; the items here take a share of theirs.
        #expect(try !grid(minimum).establishesLength(on: .vertical))
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
