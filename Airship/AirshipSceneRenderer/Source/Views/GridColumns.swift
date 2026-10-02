/* Copyright Airship and Contributors */

import Foundation
import CoreGraphics

/// The config overrides, column fit and row placement behind `grid_layout`.
enum GridColumns {
    typealias Config = ThomasViewInfo.GridLayout.Config

    /// Slack in the column fit so a width that fits a whole number of columns exactly still fits them after rounding.
    static let fitEpsilon: CGFloat = 0.5

    /// Where one item sits in the grid.
    struct Placement: Equatable, Sendable {
        /// The item's row, from 0.
        var row: Int
        /// The half-column the item starts at, from 0, so a short row can be centred half a column in.
        var halfColumn: Int
        /// The whole columns the item covers, between 1 and the column count.
        var span: Int
    }

    /// The minimum column width of `fit` columns, after any text scaling it asks for.
    ///
    /// - Parameters:
    ///   - config: the resolved config
    ///   - textScale: the text scale, 1 at the default size
    /// - Returns: the minimum in points, or `nil` for `fixed` columns or a minimum of 0 or less
    static func minColumnWidth(_ config: Config, textScale: CGFloat) -> CGFloat? {
        guard case .fit(_, let minWidth, _) = config.columns else { return nil }
        let points = self.points(minWidth, textScale: textScale)
        return points > 0 ? points : nil
    }

    /// The widest `fit` columns grow, never below their minimum: a `max_width` under `min_width` counts as it.
    ///
    /// - Parameters:
    ///   - config: the resolved config
    ///   - textScale: the text scale, 1 at the default size
    /// - Returns: the cap in points, or `nil` where columns grow to fill the grid
    static func maxColumnWidth(_ config: Config, textScale: CGFloat) -> CGFloat? {
        guard case .fit(_, _, let maxWidth?) = config.columns else { return nil }
        let points = self.points(maxWidth, textScale: textScale)
        guard points > 0 else { return nil }
        return max(points, minColumnWidth(config, textScale: textScale) ?? 0)
    }

    /// A spacing's least space: its `fixed` space or its `spread` minimum, never below 0.
    ///
    /// - Parameter spacing: a grid's column or row spacing
    /// - Returns: the space, 0 where none is set
    static func minSpace(_ spacing: ThomasViewInfo.GridLayout.Spacing?) -> CGFloat {
        let space: Double = switch spacing {
        case .fixed(let space): space
        case .spread(let minSpace, _): minSpace
        case nil: 0
        }
        return max(0, CGFloat(space))
    }

    /// A `spread` gap: `leftover` shared between the gaps of `count` columns or rows, clamped to the spacing's bounds.
    ///
    /// 84 left over by 4 columns makes 3 gaps of 28; with a `max_space` of 20 they stop at 20.
    ///
    /// - Parameters:
    ///   - spacing: a grid's column or row spacing
    ///   - leftover: the room the columns or rows leave, before any gaps
    ///   - count: how many columns or rows share it
    /// - Returns: the gap, or `nil` for `fixed` spacing or fewer than two to spread between
    static func spreadSpace(
        _ spacing: ThomasViewInfo.GridLayout.Spacing?,
        leftover: CGFloat,
        count: Int
    ) -> CGFloat? {
        guard case .spread(_, let maxSpace) = spacing, count >= 2 else { return nil }
        let minimum = minSpace(spacing)
        let maximum = maxSpace.map { max(minimum, CGFloat($0)) } ?? .infinity
        return min(maximum, max(minimum, leftover / CGFloat(count - 1)))
    }

    private static func points(_ width: ThomasViewInfo.GridLayout.ColumnWidth, textScale: CGFloat) -> CGFloat {
        let points = CGFloat(width.size)
        return switch width.type {
        case .fixed: points
        case .textScaled: points * textScale
        }
    }

    /// The column count at a width: `fixed` is its `count`; `fit` is as many columns of at least `min_width` as fit, from 1 up to `max`.
    ///
    /// 320 wide with a 44 minimum and 8 spacing fits `floor((320 + 8 + 0.5) / 52) = 6`. Unbounded, `fit` is `max`.
    ///
    /// - Parameters:
    ///   - config: the resolved config
    ///   - width: the grid's inner width, or `nil` when unbounded
    ///   - textScale: the text scale, 1 at the default size
    /// - Returns: the column count, at least 1
    static func columnCount(_ config: Config, width: CGFloat?, textScale: CGFloat) -> Int {
        let maxColumns = switch config.columns {
        case .fixed(let count): clampedCount(count, upperBound: nil)
        case .fit(let max, _, _): clampedCount(max, upperBound: nil)
        }
        guard let minWidth = minColumnWidth(config, textScale: textScale), let width else {
            return maxColumns
        }
        let spacing = minSpace(config.columnSpacing)
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
