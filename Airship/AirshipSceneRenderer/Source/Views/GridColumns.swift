/* Copyright Airship and Contributors */

import Foundation
import CoreGraphics

/// The config selection, column fit and row placement behind `grid_layout`.
enum GridColumns {
    typealias Config = ThomasViewInfo.GridLayout.Config

    /// Slack in the column fit so a width that fits a whole number of columns exactly still fits them after rounding.
    static let fitEpsilon: CGFloat = 0.5

    /// What a config selector is matched against.
    struct Environment: Equatable {
        var platform: ThomasPlatform = .ios
        var windowSize: ThomasWindowSize?
        var orientation: ThomasOrientation?
        /// The grid's inner width, or `nil` for an unbounded grid.
        var gridWidth: CGFloat?
    }

    /// Where one item sits in the grid.
    struct Placement: Equatable, Sendable {
        /// The item's row, from 0.
        var row: Int
        /// The half-column the item starts at, from 0, so a short row can be centred half a column in.
        var halfColumn: Int
        /// The whole columns the item covers, between 1 and the column count.
        var span: Int
    }

    /// Picks the first selector whose conditions all match, or `default` when none does.
    ///
    /// A selector naming `grid_width` never matches an unbounded grid.
    ///
    /// - Parameters:
    ///   - configs: the grid's `config`
    ///   - environment: what the selectors are matched against
    /// - Returns: the config to lay the grid out with
    static func resolveConfig(
        _ configs: ThomasViewInfo.GridLayout.Configs,
        environment: Environment
    ) -> Config {
        let match = configs.selectors?.first { selector in
            if let platform = selector.platform, platform != environment.platform { return false }
            if let windowSize = selector.windowSize, windowSize != environment.windowSize { return false }
            if let orientation = selector.orientation, orientation != environment.orientation { return false }
            if let range = selector.gridWidth {
                guard let width = environment.gridWidth, inRange(width, range) else { return false }
            }
            return true
        }
        return match?.config ?? configs.defaultConfig
    }

    /// Whether a length falls inside a range, both ends inclusive.
    ///
    /// - Parameters:
    ///   - length: the length in points
    ///   - range: the range to test against
    /// - Returns: true when the length is inside it
    static func inRange(_ length: CGFloat, _ range: ThomasViewInfo.GridLayout.LengthRange) -> Bool {
        if let atLeast = range.atLeast, length < atLeast { return false }
        if let atMost = range.atMost, length > atMost { return false }
        return true
    }

    /// The minimum column width after any text scaling the config asks for.
    ///
    /// - Parameters:
    ///   - config: the resolved config
    ///   - textScale: the text scale, 1 at the default size
    /// - Returns: the minimum in points, or `nil` where the config sets none or one of 0 or less
    static func minColumnWidth(_ config: Config, textScale: CGFloat) -> CGFloat? {
        guard let minWidth = config.minColumnWidth, minWidth.points > 0 else { return nil }
        let points = CGFloat(minWidth.points)
        return switch minWidth.type {
        case .fixed: points
        case .textScaled: points * textScale
        }
    }

    /// The column count at a width: as many columns of at least the minimum as fit, from 1 up to `max_columns`.
    ///
    /// 320 wide with a 44 minimum and 8 spacing fits `floor((320 + 8 + 0.5) / 52) = 6`.
    ///
    /// - Parameters:
    ///   - config: the resolved config
    ///   - width: the grid's inner width, or `nil` when unbounded
    ///   - textScale: the text scale, 1 at the default size
    /// - Returns: the column count, at least 1
    static func columnCount(_ config: Config, width: CGFloat?, textScale: CGFloat) -> Int {
        let maxColumns = clampedCount(config.maxColumns, upperBound: nil)
        guard let minWidth = minColumnWidth(config, textScale: textScale), let width else {
            return maxColumns
        }
        let spacing = CGFloat(config.columnSpacing ?? 0)
        let fits = ((width + spacing + fitEpsilon) / (minWidth + spacing)).rounded(.down)
        guard fits.isFinite else { return maxColumns }
        return Int(min(CGFloat(maxColumns), max(1, fits)))
    }

    /// Places items in rows in list order; an item that doesn't fit what's left of its row starts the next, and nothing backfills.
    ///
    /// A short row keeps its cells' widths and is offset by `alignment`: one item in 3 columns
    /// starts at half-column 0 for `start`, 2 for `center` and 4 for `end`.
    ///
    /// - Parameters:
    ///   - spans: each item's requested `column_span`, in item order
    ///   - columns: the column count, at least 1
    ///   - alignment: where a short row sits
    /// - Returns: each item's placement, in item order
    static func place(
        spans: [Double?],
        columns: Int,
        alignment: ThomasPosition.Horizontal
    ) -> [Placement] {
        var rows: [[(index: Int, span: Int)]] = []
        var row: [(index: Int, span: Int)] = []
        var used = 0
        for (index, requested) in spans.enumerated() {
            let span = clampedCount(requested ?? 1, upperBound: columns)
            if used + span > columns {
                rows.append(row)
                row = []
                used = 0
            }
            row.append((index, span))
            used += span
        }
        if !row.isEmpty { rows.append(row) }

        var placements = [Placement](repeating: Placement(row: 0, halfColumn: 0, span: 1), count: spans.count)
        for (rowIndex, cells) in rows.enumerated() {
            let leftover = columns - cells.reduce(0) { $0 + $1.span }
            var halfColumn = switch alignment {
            case .start: 0
            case .center: leftover
            case .end: 2 * leftover
            }
            for cell in cells {
                placements[cell.index] = Placement(row: rowIndex, halfColumn: halfColumn, span: cell.span)
                halfColumn += 2 * cell.span
            }
        }
        return placements
    }

    /// `floor(value)` clamped to at least 1 and, when given, at most `upperBound`; NaN counts as 1.
    private static func clampedCount(_ value: Double, upperBound: Int?) -> Int {
        let upper = Double(upperBound ?? Int(Int32.max))
        guard !value.isNaN else { return 1 }
        return Int(min(upper, max(1, value.rounded(.down))))
    }
}
