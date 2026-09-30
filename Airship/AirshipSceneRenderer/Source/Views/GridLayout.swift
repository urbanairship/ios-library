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
    @Environment(\.pageIdentifier) private var pageIdentifier

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
            edge(info.properties.header, slot: .header, metrics: metrics)
            ForEach(0..<info.properties.items.count, id: \.self) { index in
                cell(index, metrics: metrics)
            }
            edge(info.properties.footer, slot: .footer, metrics: metrics)
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
        let environment = GridColumns.Environment(
            windowSize: windowSize,
            orientation: orientation,
            gridWidth: width
        )
        let config = GridColumns.resolveConfig(info.properties.config, environment: environment)
        let textScale = CGFloat(AirshipFont.scaledSize(100) / 100)
        let columns = GridColumns.columnCount(config, width: width, textScale: textScale)
        let ratio = config.cellAspectRatio.flatMap { $0 > 0 ? CGFloat($0) : nil }

        let sizing: GridMetrics.Sizing = if let width {
            .divides(width)
        } else if let minWidth = GridColumns.minColumnWidth(config, textScale: textScale) {
            .fixed(columnWidth: minWidth)
        } else {
            .hugs
        }

        let itemConfigs = items.map { item in
            item.config.map { GridColumns.resolveConfig($0, environment: environment) }
        }
        let ordered = GridColumns.placementOrder(
            info.properties.randomizeChildren == true
                ? thomasEnvironment.shuffledOrder(count: items.count, page: pageIdentifier, identifier: nil)
                : Array(items.indices),
            orders: itemConfigs.map { $0?.order }
        )
        var readingRank = [Int](repeating: 0, count: items.count)
        for (rank, index) in ordered.enumerated() {
            readingRank[index] = rank
        }

        let visible = ordered.filter { index in
            items[index].view.commonInfo.0.visibility?.isVisible(state: thomasState.state) ?? true
        }
        let visiblePlacements = GridColumns.place(
            spans: visible.map { itemConfigs[$0]?.columnSpan },
            columns: columns,
            alignment: config.partialRowPosition ?? .start
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
            columnSpacing: config.columnSpacing,
            rowSpacing: config.rowSpacing,
            contentPosition: config.contentPosition ?? GridMetrics.defaultContentPosition,
            sizing: sizing,
            maxColumnWidth: GridColumns.maxColumnWidth(config, textScale: textScale),
            fillsOffer: fillsOffer && width != nil,
            aspectRatio: ratio,
            placements: placements,
            rowHasBasis: rowHasBasis,
            hasPercentHeights: ratio == nil && visible.contains { items[$0].resolvedSize.height.isPercent },
            readingRank: readingRank
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
        // SwiftUI orders VoiceOver by position; reading order is placement order.
        .accessibilitySortPriority(Double(info.properties.items.count - metrics.readingRank[index]))
        .layoutValue(
            key: GridCellsLayout.CellKey.self,
            value: cell.map {
                GridCellsLayout.Cell(
                    slot: .cell($0.placement),
                    position: item.resolvedPosition,
                    rowShare: $0.rowShare
                )
            }
        )
    }

    /// A header or footer: a row of its own, as wide as the block of columns, outside the list of items.
    @ViewBuilder
    @MainActor
    private func edge(
        _ edge: ThomasViewInfo.GridLayout.Edge?,
        slot: GridCellsLayout.Cell.Slot,
        metrics: GridMetrics
    ) -> some View {
        if let edge {
            let isVisible = edge.view.commonInfo.0.visibility?.isVisible(state: thomasState.state) ?? true

            thomasEnvironment.viewFactory.createView(
                edge.view,
                constraints: edgeConstraints(edge, metrics: metrics)
            )
            .margin(edge.margin)
            .accessibilitySortPriority(slot == .header ? Double(info.properties.items.count + 1) : 0)
            .layoutValue(
                key: GridCellsLayout.CellKey.self,
                value: isVisible
                    ? GridCellsLayout.Cell(slot: slot, position: edge.resolvedPosition, rowShare: nil)
                    : nil
            )
        }
    }

    private func edgeConstraints(_ edge: ThomasViewInfo.GridLayout.Edge, metrics: GridMetrics) -> ViewConstraints {
        var size = edge.resolvedSize
        // Its row is as tall as it is, so a percentage there has nothing to be a share of.
        if size.height.isPercent { size.height = .auto }
        let width = metrics.spanWidth(metrics.columns)
        return ViewConstraints(width: width, maxWidth: width).childConstraints(
            size,
            margin: edge.margin,
            borderStrokeWidth: edge.view.borderStrokeWidth,
            safeAreaInsetsMode: .consume
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

    static let defaultContentPosition: ThomasPosition = ThomasPosition(horizontal: .start, vertical: .top)

    var columns: Int
    var columnSpacing: ThomasViewInfo.GridLayout.Spacing?
    var rowSpacing: ThomasViewInfo.GridLayout.Spacing?
    var contentPosition: ThomasPosition
    var sizing: Sizing
    /// The widest a column grows when the grid divides its width.
    var maxColumnWidth: CGFloat?
    /// Whether the grid takes the width it is proposed rather than a length of its own.
    var fillsOffer: Bool
    var aspectRatio: CGFloat?
    /// Each item's placement, in item order; `nil` for a hidden item.
    var placements: [GridColumns.Placement?]
    /// Whether something in each row gives it a height of its own.
    var rowHasBasis: [Bool]
    var hasPercentHeights: Bool
    /// Each item's position in placement and reading order, by item index.
    var readingRank: [Int]

    var minColumnSpacing: CGFloat { GridColumns.minSpace(columnSpacing) }
    var minRowSpacing: CGFloat { GridColumns.minSpace(rowSpacing) }

    /// One column's width, or `nil` when columns size to their content.
    var columnWidth: CGFloat? {
        switch sizing {
        case .divides(let width): columns(dividing: width).width
        case .fixed(let columnWidth): columnWidth
        case .hugs: nil
        }
    }

    /// The space between columns at the grid's own width.
    var columnGap: CGFloat {
        guard case .divides(let width) = sizing else { return minColumnSpacing }
        return columns(dividing: width).spacing
    }

    /// Every row's height where the ratio and a known column width decide it.
    var fixedRowHeight: CGFloat? {
        guard let aspectRatio, let columnWidth else { return nil }
        return columnWidth / aspectRatio
    }

    /// A column's width and the space between columns when `width` is divided among them.
    ///
    /// The share uses the minimum space. Past `maxColumnWidth` the columns stop growing, and
    /// `spread` spacing takes the room they leave: 4 columns capped at 64 in 340 get gaps of 28.
    func columns(dividing width: CGFloat) -> (width: CGFloat, spacing: CGFloat) {
        let minimum = minColumnSpacing
        let share = max(0, (width - CGFloat(columns - 1) * minimum) / CGFloat(columns))
        guard let cap = maxColumnWidth, share > cap else { return (share, minimum) }
        let spread = GridColumns.spreadSpace(
            columnSpacing,
            leftover: width - CGFloat(columns) * cap,
            count: columns
        )
        return (cap, spread ?? minimum)
    }

    /// The width of a cell covering `span` columns, or `nil` when columns size to their content.
    func spanWidth(_ span: Int) -> CGFloat? {
        columnWidth.map { CGFloat(span) * $0 + CGFloat(span - 1) * columnGap }
    }
}

/// Places grid cells on half-column tracks so a short row can start half a column in.
///
/// Each column is two tracks with the column spacing between every track, which keeps a column
/// exactly `(W - (n - 1) * g) / n` wide.
struct GridCellsLayout: Layout {
    struct Cell: Equatable {
        enum Slot: Equatable {
            case cell(GridColumns.Placement)
            /// A row above the cells, spanning the block of columns.
            case header
            /// A row below the cells, spanning the block of columns.
            case footer
        }

        var slot: Slot
        var position: ThomasPosition

        /// The cell's row, or `nil` for a header or footer.
        var row: Int? {
            if case .cell(let placement) = slot { placement.row } else { nil }
        }

        /// The columns the view covers: its placement, or every column for a header or footer.
        func columns(_ count: Int) -> GridColumns.Placement {
            if case .cell(let placement) = slot { placement } else { GridColumns.Placement(row: 0, halfColumn: 0, span: count) }
        }
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
        var headerHeight: CGFloat?
        var footerHeight: CGFloat?
        /// The space between columns.
        var spacing: CGFloat = 0
        /// The space between two rows of cells; the header and footer keep the minimum.
        var rowGap: CGFloat = 0
        /// Each row's top, and the header's and footer's, from the top of the block of rows.
        var headerY: CGFloat = 0
        var rowY: [CGFloat] = []
        var footerY: CGFloat = 0
        /// How far the block of columns sits from the grid's leading edge, where it is narrower than the grid.
        var leadingOffset: CGFloat = 0

        func x(halfColumn: Int, spacing: CGFloat) -> CGFloat {
            leadingOffset + halfTracks.prefix(halfColumn).reduce(0, +) + CGFloat(halfColumn) * spacing
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
        let solution = solve(
            subviews,
            width: width(for: proposal),
            height: definiteHeight ? proposal.height?.safeValue : nil
        )
        let height = definiteHeight ? (proposal.height?.safeValue ?? solution.height) : solution.height
        return CGSize(width: solution.width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let solution = solve(subviews, width: bounds.width, height: definiteHeight ? bounds.height : nil)
        let spacing = solution.spacing

        let leftoverHeight = bounds.height - solution.height
        let rowsOffset: CGFloat = switch metrics.contentPosition.vertical {
        case .top: 0
        case .center: leftoverHeight / 2
        case .bottom: leftoverHeight
        }
        let top = bounds.minY + rowsOffset
        let headerY = top + solution.headerY
        let rowY = solution.rowY.map { top + $0 }
        let footerY = top + solution.footerY

        for subview in subviews {
            guard let cell = subview[CellKey.self] else {
                subview.place(at: bounds.origin, proposal: .zero)
                continue
            }
            let placement = cell.columns(metrics.columns)
            let top: CGFloat
            let rowHeight: CGFloat
            switch cell.slot {
            case .header:
                top = headerY
                rowHeight = solution.headerHeight ?? 0
            case .footer:
                top = footerY
                rowHeight = solution.footerHeight ?? 0
            case .cell(let placement):
                guard placement.row < rowY.count else {
                    subview.place(at: bounds.origin, proposal: .zero)
                    continue
                }
                top = rowY[placement.row]
                rowHeight = solution.rowHeights[placement.row]
            }
            let width = solution.spanWidth(halfColumn: placement.halfColumn, span: placement.span, spacing: spacing)
            let leadingX = solution.x(halfColumn: placement.halfColumn, spacing: spacing)
            let x = layoutDirection == .rightToLeft
                ? bounds.maxX - leadingX - width
                : bounds.minX + leadingX
            let cellRect = CGRect(x: x, y: top, width: width, height: rowHeight)

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

    /// - Parameters:
    ///   - width: the inner width a bounded grid divides; ignored for an unbounded one
    ///   - height: the grid's own height, which `spread` rows share out; `nil` for an `auto` height
    private func solve(_ subviews: Subviews, width: CGFloat?, height: CGFloat?) -> Solution {
        let trackCount = 2 * metrics.columns
        let cells = subviews.compactMap { subview in subview[CellKey.self].map { (subview, $0) } }

        let divided = if case .divides = metrics.sizing, let width { metrics.columns(dividing: width) } else { nil as (width: CGFloat, spacing: CGFloat)? }
        let spacing = divided?.spacing ?? metrics.minColumnSpacing
        let columnWidth: CGFloat? = switch metrics.sizing {
        case .divides: divided?.width
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
                let placement = cell.columns(metrics.columns)
                let natural = subview.sizeThatFits(.unspecified).width.safeValue ?? 0
                let share = max(0, (natural - CGFloat(2 * placement.span - 1) * spacing) / CGFloat(2 * placement.span))
                let end = min(trackCount, placement.halfColumn + 2 * placement.span)
                for track in min(placement.halfColumn, end)..<end {
                    halfTracks[track] = max(halfTracks[track], share)
                }
            }
        }

        var solution = Solution(halfTracks: halfTracks, rowHeights: [], width: 0, height: 0)
        solution.spacing = spacing
        let blockWidth = max(0, halfTracks.reduce(0, +) + CGFloat(trackCount - 1) * spacing)
        // A bounded grid keeps its width when capped columns leave it wider than they are.
        let dividedWidth: CGFloat = if case .divides = metrics.sizing { width ?? 0 } else { 0 }
        solution.width = max(blockWidth, dividedWidth)
        let leftover = solution.width - blockWidth
        solution.leadingOffset = switch metrics.contentPosition.horizontal {
        case .start: 0
        case .center: leftover / 2
        case .end: leftover
        }

        // Percentage heights are floored at their share, so measuring them unproposed gives the
        // larger of the share and their content: a row is as tall as its tallest content.
        let rowCount = (cells.compactMap(\.1.row).max() ?? -1) + 1
        var rowHeights = [CGFloat](repeating: 0, count: rowCount)
        for (subview, cell) in cells {
            let placement = cell.columns(metrics.columns)
            let width = solution.spanWidth(halfColumn: placement.halfColumn, span: placement.span, spacing: spacing)
            // A header or footer keeps its own height, even beside rows a ratio sets.
            guard case .cell(let placement) = cell.slot else {
                let height = subview.sizeThatFits(ProposedViewSize(width: width, height: nil)).height.safeValue ?? 0
                if cell.slot == .header { solution.headerHeight = height } else { solution.footerHeight = height }
                continue
            }
            let rowHeight: CGFloat
            if let ratio = metrics.aspectRatio {
                // One column's width sets the height, so a spanning cell isn't taller than its row.
                rowHeight = (width - CGFloat(placement.span - 1) * spacing) / CGFloat(placement.span) / ratio
            } else {
                rowHeight = subview.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
            }
            rowHeights[placement.row] = max(rowHeights[placement.row], rowHeight.safeValue ?? 0)
        }
        solution.rowHeights = rowHeights
        stackRows(&solution, height: height)
        return solution
    }

    /// Places the header, rows and footer top to bottom, spreading the gaps between rows into `height` when asked.
    ///
    /// The header and footer sit the minimum row space from the cells. Rows spread only into a
    /// height the grid has of its own, and only between two rows or more.
    private func stackRows(_ solution: inout Solution, height: CGFloat?) {
        let minimum = metrics.minRowSpacing
        let rows = solution.rowHeights
        let edges = [solution.headerHeight, solution.footerHeight].compactMap { $0 }.reduce(0) { $0 + $1 + minimum }
        solution.rowGap = height.flatMap {
            GridColumns.spreadSpace(metrics.rowSpacing, leftover: $0 - edges - rows.reduce(0, +), count: rows.count)
        } ?? minimum

        var y: CGFloat = 0
        if let headerHeight = solution.headerHeight {
            solution.headerY = 0
            y = headerHeight
        }
        solution.rowY = []
        for (index, rowHeight) in rows.enumerated() {
            if index > 0 {
                y += solution.rowGap
            } else if solution.headerHeight != nil {
                y += minimum
            }
            solution.rowY.append(y)
            y += rowHeight
        }
        if let footerHeight = solution.footerHeight {
            if !rows.isEmpty || solution.headerHeight != nil { y += minimum }
            solution.footerY = y
            y += footerHeight
        }
        solution.height = y
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
