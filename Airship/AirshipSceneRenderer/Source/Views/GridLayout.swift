/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
@_spi(AirshipInternal) import AirshipBasement

/// Grid layout: rows of equal-width cells whose column count comes from the grid's own width.
struct GridLayout: View {
    @EnvironmentObject private var thomasEnvironment: ThomasEnvironment
    @EnvironmentObject private var thomasState: ThomasState
    @Environment(\.windowSize) private var windowSize
    @Environment(\.orientation) private var orientation
    @Environment(\.layoutDirection) private var layoutDirection
    // Read so a text size change re-renders a `text_scaled` minimum.
    @Environment(\.sizeCategory) private var sizeCategory

    private let info: ThomasViewInfo.GridLayout
    private let constraints: ViewConstraints

    /// The inner width an `auto` grid was last laid out at, which a sibling in a stack can make narrower than the offer.
    @State private var measuredWidth: CGFloat?

    /// Each row's height from the last layout pass, the base its percentage heights resolve against.
    @State private var measuredRowHeights: [CGFloat] = []

    init(info: ThomasViewInfo.GridLayout, constraints: ViewConstraints) {
        self.info = info
        self.constraints = constraints
    }

    var body: some View {
        let metrics = makeMetrics()
        GridCellsLayout(
            metrics: metrics,
            layoutDirection: layoutDirection,
            definiteHeight: constraints.height != nil,
            measuredWidth: metrics.fillsOffer ? $measuredWidth : nil,
            measuredRowHeights: metrics.hasPercentHeights ? $measuredRowHeights : nil
        ) {
            ForEach(0..<info.properties.items.count, id: \.self) { index in
                cell(index, metrics: metrics)
            }
        }
        .accessibilityElement(children: .contain)
        .constraints(constraints, alignment: .top)
        .clipped()
        // Kept out of sight until measured, so the first frame never shows the wrong columns or row heights.
        .opacity(isAwaitingMeasurement(metrics) ? 0 : 1)
        .thomasBackgrounds(info.properties.backgrounds)
        .thomasCommon(info)
    }

    private func isAwaitingMeasurement(_ metrics: GridMetrics) -> Bool {
        (metrics.fillsOffer && measuredWidth == nil)
            || (metrics.hasPercentHeights && measuredRowHeights.isEmpty)
    }

    /// Whether the grid takes its width from what its parent offers rather than a length of its own.
    private var fillsOffer: Bool {
        constraints.width == nil && !constraints.scrollingAxes.contains(.horizontal)
    }

    /// The grid's inner width, or `nil` when nothing offers it one.
    ///
    /// `auto` fills what the parent offers rather than hugging the cells, which would make the column
    /// count depend on the items. Under a horizontal scroll the offer is the viewport, not a bound.
    private var gridWidth: CGFloat? {
        if let width = constraints.width?.safeValue, !constraints.uncappedAxes.contains(.horizontal) {
            return width
        }
        guard fillsOffer else { return nil }
        if let measuredWidth { return measuredWidth }
        let stroke = CGFloat(info.commonProperties.border?.strokeWidth ?? 0) * 2
        return constraints.maxWidth?.safeValue.map { max(0, $0 - stroke) }
    }

    private func makeMetrics() -> GridMetrics {
        let items = info.properties.items
        let width = gridWidth
        let config = GridColumns.resolveConfig(
            info.properties.config,
            environment: GridColumns.Environment(
                windowSize: windowSize,
                orientation: orientation,
                gridWidth: width
            )
        )
        let textScale = CGFloat(AirshipFont.scaledSize(100) / 100)
        let columns = GridColumns.columnCount(config, width: width, textScale: textScale)
        let spacing = CGFloat(config.columnSpacing ?? 0)
        let ratio = config.cellAspectRatio.flatMap { $0 > 0 ? CGFloat($0) : nil }

        let sizing: GridMetrics.Sizing = if let width {
            .divides(width)
        } else if let minWidth = GridColumns.minColumnWidth(config, textScale: textScale) {
            .fixed(columnWidth: minWidth)
        } else {
            .hugs
        }

        let visible = items.indices.filter { index in
            items[index].view.commonInfo.0.visibility?.isVisible(state: thomasState.state) ?? true
        }
        let visiblePlacements = GridColumns.place(
            spans: visible.map { items[$0].columnSpan },
            columns: columns,
            alignment: config.partialRowAlignment ?? .start
        )
        var placements = [GridColumns.Placement?](repeating: nil, count: items.count)
        for (placement, index) in zip(visiblePlacements, visible) {
            placements[index] = placement
        }

        let rowCount = (visiblePlacements.map(\.row).max() ?? -1) + 1
        var rowHasBasis = [Bool](repeating: ratio != nil, count: rowCount)
        if ratio == nil {
            for (placement, index) in zip(visiblePlacements, visible) where !rowHasBasis[placement.row] {
                let item = items[index]
                rowHasBasis[placement.row] = item.resolvedSize.height
                    .establishesLength(view: item.view, on: .vertical)
            }
        }

        return GridMetrics(
            columns: columns,
            columnSpacing: spacing,
            rowSpacing: CGFloat(config.rowSpacing ?? 0),
            rowAlignment: config.rowAlignment ?? .top,
            sizing: sizing,
            fillsOffer: fillsOffer && width != nil,
            aspectRatio: ratio,
            placements: placements,
            rowHasBasis: rowHasBasis,
            hasPercentHeights: ratio == nil && visible.contains { items[$0].resolvedSize.height.isPercent }
        )
    }

    @ViewBuilder
    @MainActor
    private func cell(_ index: Int, metrics: GridMetrics) -> some View {
        let item = info.properties.items[index]
        let placement = metrics.placements[index]
        let cell = placement.map { cellInfo(item, placement: $0, metrics: metrics) }

        thomasEnvironment.viewFactory.createView(
            item.view,
            constraints: cell?.constraints ?? ViewConstraints()
        )
        .margin(item.margin)
        // SwiftUI orders VoiceOver by position; reading order is list order.
        .accessibilitySortPriority(Double(info.properties.items.count - index))
        .layoutValue(
            key: GridCellsLayout.CellKey.self,
            value: cell.map {
                GridCellsLayout.Cell(
                    placement: $0.placement,
                    position: item.resolvedPosition,
                    rowShare: $0.rowShare
                )
            }
        )
    }

    private struct CellInfo {
        var placement: GridColumns.Placement
        var constraints: ViewConstraints
        var rowShare: CGFloat?
    }

    private func cellInfo(
        _ item: ThomasViewInfo.GridLayout.Item,
        placement: GridColumns.Placement,
        metrics: GridMetrics
    ) -> CellInfo {
        var size = item.resolvedSize

        // As across a horizontal stack: with nothing in the row to take a share of, a share under the
        // whole hugs its content. The whole still takes the row, so a row of 100% cards is one height.
        if !metrics.rowHasBasis[placement.row], let fraction = size.height.percentFraction, fraction < 1 {
            size.height = .auto
        }

        let cellWidth = metrics.spanWidth(placement.span)
        let fixedRowHeight = metrics.fixedRowHeight
        let rowShare = fixedRowHeight == nil ? size.height.percentFraction : nil
        let measuredRowHeight = rowShare == nil
            ? nil
            : measuredRowHeights[safe: placement.row].flatMap { $0 > 0 ? $0 : nil }
        let rowHeight = fixedRowHeight ?? measuredRowHeight

        var cell = ViewConstraints(
            width: cellWidth,
            height: rowHeight,
            maxWidth: cellWidth,
            maxHeight: rowHeight ?? constraints.maxHeight,
            isHorizontalFixedSize: cellWidth != nil,
            isVerticalFixedSize: fixedRowHeight != nil
        )
        if measuredRowHeight != nil {
            cell.measuredAxes.insert(.vertical)
        }

        var child = cell
            .childConstraints(
                size,
                margin: item.margin,
                borderStrokeWidth: item.view.borderStrokeWidth,
                safeAreaInsetsMode: .consume
            )
            .flooringMeasuredShare(of: size, on: measuredRowHeight == nil ? [] : .vertical)

        // A share is floored rather than fixed so the row can measure the content it would hug, as
        // web sizes a row with its percentages taken as auto; the layout then proposes the share.
        if measuredRowHeight != nil, size.aspectRatio == nil, let share = child.height {
            child.height = nil
            child.minHeight = max(child.minHeight ?? 0, share)
        }

        // An item wider than its cell stops at the cell rather than running into the next one.
        if let cellWidth {
            let available = max(0, cellWidth - (item.margin?.horizontalMargins ?? 0))
            let stroke = CGFloat(item.view.borderStrokeWidth * 2)
            child.width = child.width.map { min($0, max(0, available - stroke)) }
            child.maxWidth = child.maxWidth.map { min($0, available) }
        }

        return CellInfo(placement: placement, constraints: child, rowShare: rowShare)
    }
}

/// The resolved geometry a grid lays out with, fixed for a render so measuring and placing agree.
struct GridMetrics: Equatable {
    enum Sizing: Equatable {
        /// A bounded grid divides its inner width, known here, among its columns.
        case divides(CGFloat)
        /// An unbounded grid with a minimum draws columns of exactly that width.
        case fixed(columnWidth: CGFloat)
        /// An unbounded grid with no minimum sizes its columns to their content.
        case hugs
    }

    var columns: Int
    var columnSpacing: CGFloat
    var rowSpacing: CGFloat
    var rowAlignment: ThomasPosition.Vertical
    var sizing: Sizing
    /// Whether the grid takes the width it is proposed rather than a length of its own.
    var fillsOffer: Bool
    var aspectRatio: CGFloat?
    /// Each item's placement, in item order; `nil` for a hidden item.
    var placements: [GridColumns.Placement?]
    /// Whether something in each row gives it a height of its own.
    var rowHasBasis: [Bool]
    var hasPercentHeights: Bool

    /// One column's width, or `nil` when columns size to their content.
    var columnWidth: CGFloat? {
        switch sizing {
        case .divides(let width): columnWidth(dividing: width)
        case .fixed(let columnWidth): columnWidth
        case .hugs: nil
        }
    }

    /// Every row's height where the ratio and a known column width decide it.
    var fixedRowHeight: CGFloat? {
        guard let aspectRatio, let columnWidth else { return nil }
        return columnWidth / aspectRatio
    }

    /// One column's width when `width` is divided among the columns.
    func columnWidth(dividing width: CGFloat) -> CGFloat {
        max(0, (width - CGFloat(columns - 1) * columnSpacing) / CGFloat(columns))
    }

    /// The width of a cell covering `span` columns, or `nil` when columns size to their content.
    func spanWidth(_ span: Int) -> CGFloat? {
        columnWidth.map { CGFloat(span) * $0 + CGFloat(span - 1) * columnSpacing }
    }
}

/// Places grid cells on half-column tracks so a short row can start half a column in.
///
/// Each column is two tracks with the column spacing between every track, which keeps a column
/// exactly `(W - (n - 1) * g) / n` wide.
struct GridCellsLayout: Layout {
    struct Cell: Equatable {
        var placement: GridColumns.Placement
        var position: ThomasPosition
        /// The fraction of its row a percentage height takes, proposed once the row is measured.
        var rowShare: CGFloat?
    }

    struct CellKey: LayoutValueKey {
        static let defaultValue: Cell? = nil
    }

    let metrics: GridMetrics
    let layoutDirection: LayoutDirection
    /// Whether the grid has a height of its own, which `row_alignment` places the rows within.
    let definiteHeight: Bool
    /// Where the width an `auto` grid is laid out at is reported back, for its columns to divide.
    let measuredWidth: Binding<CGFloat?>?
    /// Where row heights are reported back, for percentage heights to resolve against.
    let measuredRowHeights: Binding<[CGFloat]>?

    private struct Solution {
        var halfTracks: [CGFloat]
        var rowHeights: [CGFloat]
        var width: CGFloat
        var height: CGFloat

        func x(halfColumn: Int, spacing: CGFloat) -> CGFloat {
            halfTracks.prefix(halfColumn).reduce(0, +) + CGFloat(halfColumn) * spacing
        }

        func spanWidth(halfColumn: Int, span: Int, spacing: CGFloat) -> CGFloat {
            let end = min(halfTracks.count, halfColumn + 2 * span)
            let tracks = halfTracks[min(halfColumn, end)..<end].reduce(0, +)
            return tracks + CGFloat(2 * span - 1) * spacing
        }
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let solution = solve(subviews, width: width(for: proposal))
        let height = definiteHeight ? (proposal.height?.safeValue ?? solution.height) : solution.height
        return CGSize(width: solution.width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let solution = solve(subviews, width: bounds.width)
        let spacing = metrics.columnSpacing

        let leftoverHeight = bounds.height - solution.height
        let rowsOffset: CGFloat = switch metrics.rowAlignment {
        case .top: 0
        case .center: leftoverHeight / 2
        case .bottom: leftoverHeight
        }
        var y = bounds.minY + rowsOffset
        var rowY: [CGFloat] = []
        for height in solution.rowHeights {
            rowY.append(y)
            y += height + metrics.rowSpacing
        }

        for subview in subviews {
            guard let cell = subview[CellKey.self], cell.placement.row < rowY.count else {
                subview.place(at: bounds.origin, proposal: .zero)
                continue
            }
            let placement = cell.placement
            let width = solution.spanWidth(halfColumn: placement.halfColumn, span: placement.span, spacing: spacing)
            let rowHeight = solution.rowHeights[placement.row]
            let leadingX = solution.x(halfColumn: placement.halfColumn, spacing: spacing)
            let x = layoutDirection == .rightToLeft
                ? bounds.maxX - leadingX - width
                : bounds.minX + leadingX
            let cellRect = CGRect(x: x, y: rowY[placement.row], width: width, height: rowHeight)

            let cellProposal = ProposedViewSize(width: width, height: rowHeight * (cell.rowShare ?? 1))
            let size = subview.dimensions(in: cellProposal)
            subview.place(
                at: origin(of: size, in: cellRect, position: cell.position),
                proposal: cellProposal
            )
        }

        if metrics.fillsOffer {
            report(bounds.width, to: measuredWidth)
        }
        report(solution.rowHeights, to: measuredRowHeights)
    }

    /// The width a bounded grid divides: what it is proposed when it fills the offer, else its own.
    private func width(for proposal: ProposedViewSize) -> CGFloat? {
        guard case .divides(let width) = metrics.sizing else { return nil }
        guard metrics.fillsOffer, let proposed = proposal.width?.safeValue else { return width }
        return proposed
    }

    private func origin(of size: ViewDimensions, in rect: CGRect, position: ThomasPosition) -> CGPoint {
        let isRTL = layoutDirection == .rightToLeft
        let width = size.width.safeValue ?? 0
        let height = size.height.safeValue ?? 0
        let x: CGFloat = switch position.horizontal {
        case .start: isRTL ? rect.maxX - width : rect.minX
        case .end: isRTL ? rect.minX : rect.maxX - width
        case .center: rect.midX - width / 2
        }
        let y: CGFloat = switch position.vertical {
        case .top: rect.minY
        case .bottom: rect.maxY - height
        case .center: rect.midY - height / 2
        }
        return CGPoint(x: x.safeValue ?? rect.minX, y: y.safeValue ?? rect.minY)
    }

    /// - Parameter width: the inner width a bounded grid divides; ignored for an unbounded one
    private func solve(_ subviews: Subviews, width: CGFloat?) -> Solution {
        let spacing = metrics.columnSpacing
        let trackCount = 2 * metrics.columns
        let cells = subviews.compactMap { subview in subview[CellKey.self].map { (subview, $0) } }

        let columnWidth: CGFloat? = switch metrics.sizing {
        case .divides: width.map { metrics.columnWidth(dividing: $0) }
        case .fixed(let columnWidth): columnWidth
        case .hugs: nil
        }

        var halfTracks: [CGFloat]
        if let columnWidth {
            halfTracks = Array(repeating: (columnWidth - spacing) / 2, count: trackCount)
        } else {
            // Columns size to their content: each cell spreads its width over the tracks it covers.
            halfTracks = Array(repeating: 0, count: trackCount)
            for (subview, cell) in cells {
                let placement = cell.placement
                let natural = subview.sizeThatFits(.unspecified).width.safeValue ?? 0
                let share = max(0, (natural - CGFloat(2 * placement.span - 1) * spacing) / CGFloat(2 * placement.span))
                let end = min(trackCount, placement.halfColumn + 2 * placement.span)
                for track in min(placement.halfColumn, end)..<end {
                    halfTracks[track] = max(halfTracks[track], share)
                }
            }
        }

        var solution = Solution(halfTracks: halfTracks, rowHeights: [], width: 0, height: 0)
        solution.width = max(0, halfTracks.reduce(0, +) + CGFloat(trackCount - 1) * spacing)

        // Percentage heights are floored at their share, so measuring them unproposed gives the
        // larger of the share and their content: a row is as tall as its tallest content.
        let rowCount = (cells.map(\.1.placement.row).max() ?? -1) + 1
        var rowHeights = [CGFloat](repeating: 0, count: rowCount)
        for (subview, cell) in cells {
            let placement = cell.placement
            let width = solution.spanWidth(halfColumn: placement.halfColumn, span: placement.span, spacing: spacing)
            let height: CGFloat
            if let ratio = metrics.aspectRatio {
                // One column's width sets the height, so a spanning cell isn't taller than its row.
                height = (width - CGFloat(placement.span - 1) * spacing) / CGFloat(placement.span) / ratio
            } else {
                height = subview.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
            }
            rowHeights[placement.row] = max(rowHeights[placement.row], height.safeValue ?? 0)
        }
        solution.rowHeights = rowHeights
        solution.height = rowHeights.reduce(0, +) + CGFloat(max(0, rowCount - 1)) * metrics.rowSpacing
        return solution
    }

    private func report(_ width: CGFloat, to binding: Binding<CGFloat?>?) {
        guard let binding else { return }
        DispatchQueue.main.async {
            if let current = binding.wrappedValue, abs(current - width) < 0.5 { return }
            binding.wrappedValue = width
        }
    }

    private func report(_ heights: [CGFloat], to binding: Binding<[CGFloat]>?) {
        guard let binding else { return }
        DispatchQueue.main.async {
            let current = binding.wrappedValue
            // Half a point of tolerance so rounding can't keep the loop alive.
            let unchanged = current.count == heights.count
                && zip(current, heights).allSatisfy { abs($0 - $1) < 0.5 }
            guard !unchanged else { return }
            binding.wrappedValue = heights
        }
    }
}

fileprivate extension ThomasSizeConstraint {
    var percentFraction: CGFloat? {
        if case .percent(let percent) = self { return percent / 100 }
        return nil
    }
}

fileprivate extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
