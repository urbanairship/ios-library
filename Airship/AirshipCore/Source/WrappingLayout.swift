/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Wrapping layout will attempt to wrap items with a specified max items per line when parent width
/// is constrained. Display can break when parent height is exceeded - especially in landscape or when excessive
/// item padding is specified.
internal struct WrappingLayout: Layout {
    /// View constraints to apply
    var viewConstraints: ViewConstraints

    /// Minimum number of lines to display
    var minLines: Int
    private static let defaultMinLines: Int = 1

    /// Spacing applied around each item
    var itemSpacing: CGFloat
    private static let defaultItemSpacing: CGFloat = 0

    /// Spacing applied for each wrapped line
    var lineSpacing: CGFloat
    private static let defaultLineSpacing: CGFloat = 0

    /// Maximum number of items to display per line
    var maxItemsPerLine: Int
    private static let defaultMaxItemsPerLine: Int = 11

    init(
        viewConstraints: ViewConstraints,
        minLines: Int? = Self.defaultMinLines,
        itemSpacing: CGFloat? = Self.defaultItemSpacing,
        lineSpacing: CGFloat? = Self.defaultLineSpacing,
        maxItemsPerLine: Int? = Self.defaultMaxItemsPerLine
    ) {
        self.viewConstraints = viewConstraints
        self.minLines = minLines ?? Self.defaultMinLines
        self.itemSpacing = itemSpacing ?? Self.defaultItemSpacing
        self.lineSpacing = lineSpacing ?? Self.defaultLineSpacing
        self.maxItemsPerLine = maxItemsPerLine ?? Self.defaultMaxItemsPerLine
    }

    
    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard !subviews.isEmpty else {
            AirshipLogger.debug("WrappingLayout - subviews are empty. Returning zero size.")
            return .zero
        }

        // Get the maximum width and height of the subviews
        let itemSizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let itemWidth = itemSizes.map { $0.width }.max() ?? 0
        let itemHeight = itemSizes.map { $0.height }.max() ?? 0

        let totalItems = subviews.count

        // Determine the maximum width from viewConstraints or proposal
        let maxWidth = viewConstraints.width ?? proposal.width ?? viewConstraints.maxWidth ?? .infinity

        // Calculate the number of items per line
        let itemsInLine = calculateItemsInLine(
            totalItems: totalItems,
            maxItemsPerLine: maxItemsPerLine,
            itemWidth: itemWidth,
            itemSpacing: itemSpacing,
            maxWidth: maxWidth
        )

        let linesNeeded = calculateLinesNeeded(totalItems: totalItems, itemsInLine: itemsInLine)

        // Calculate total height
        let totalHeight = calculateTotalHeight(linesNeeded: linesNeeded, itemHeight: itemHeight, lineSpacing: lineSpacing)

        // Apply viewConstraints maxHeight if available
        let finalHeight = min(totalHeight, viewConstraints.maxHeight ?? totalHeight)
        let finalWidth = min(maxWidth, viewConstraints.maxWidth ?? maxWidth)

        return CGSize(width: finalWidth, height: finalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard !subviews.isEmpty else {
            AirshipLogger.debug("WrappingLayout - subviews are empty.")
            return
        }

        // Get the maximum width and height of the subviews
        let itemSizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let itemWidth = itemSizes.map { $0.width }.max() ?? 0
        let itemHeight = itemSizes.map { $0.height }.max() ?? 0

        let totalItems = subviews.count

        // Use bounds width and height directly
        let availableWidth = bounds.width
        let availableHeight = bounds.height

        // Calculate the number of items per line
        let itemsInLine = calculateItemsInLine(
            totalItems: totalItems,
            maxItemsPerLine: maxItemsPerLine,
            itemWidth: itemWidth,
            itemSpacing: itemSpacing,
            maxWidth: availableWidth
        )

        let linesNeeded = calculateLinesNeeded(totalItems: totalItems, itemsInLine: itemsInLine)

        // Calculate total content height
        let totalContentHeight = calculateTotalHeight(linesNeeded: linesNeeded, itemHeight: itemHeight, lineSpacing: lineSpacing)

        // Adjust yPosition to center content vertically
        var yPosition = bounds.minY + (availableHeight - totalContentHeight) / 2.0

        var currentIndex = 0

        for _ in 0..<linesNeeded {
            let itemsInThisLine = min(itemsInLine, totalItems - currentIndex)
            let totalLineWidth = CGFloat(itemsInThisLine) * itemWidth + CGFloat(itemsInThisLine - 1) * itemSpacing

            // Center the line within the available width
            var xPosition = bounds.minX + (availableWidth - totalLineWidth) / 2.0

            for _ in 0..<itemsInThisLine {
                if currentIndex >= subviews.count { break }
                let subview = subviews[currentIndex]
                let subviewProposal = ProposedViewSize(width: itemWidth, height: itemHeight)
                subview.place(
                    at: CGPoint(x: xPosition, y: yPosition),
                    anchor: .topLeading,
                    proposal: subviewProposal
                )
                xPosition += itemWidth + itemSpacing
                currentIndex += 1
            }
            yPosition += itemHeight + lineSpacing
        }
    }

    // MARK: - Utilities
    private func calculateLinesNeeded(
        totalItems: Int,
        itemsInLine: Int
    ) -> Int {
        let safeItemsInLine = itemsInLine > 0 ? itemsInLine : 1
        return max(minLines, Int(ceil(Double(totalItems) / Double(safeItemsInLine))))
    }

    private func calculateTotalHeight(
        linesNeeded: Int,
        itemHeight: CGFloat,
        lineSpacing: CGFloat
    ) -> CGFloat {
        return CGFloat(linesNeeded) * itemHeight + CGFloat(linesNeeded - 1) * lineSpacing
    }

    private func calculateItemsInLine(
        totalItems: Int,
        maxItemsPerLine: Int,
        itemWidth: CGFloat,
        itemSpacing: CGFloat,
        maxWidth: CGFloat
    ) -> Int {
        var itemsInLine = min(totalItems, maxItemsPerLine)
        while (CGFloat(itemsInLine) * itemWidth + CGFloat(itemsInLine - 1) * itemSpacing) > maxWidth && itemsInLine > 1 {
            itemsInLine -= 1
        }
        return itemsInLine
    }

}
