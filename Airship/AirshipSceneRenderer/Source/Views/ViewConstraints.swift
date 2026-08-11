/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

struct ViewConstraints: Equatable {

    enum SafeAreaInsetsMode {
        // Insets will be passed on to children
        case ignore

        // Insets will be consumed
        case consume

        // Insets will be consumed and applied as margins if the size is percent
        case consumeMargin
    }

    static let emptyEdgeSet: EdgeInsets = EdgeInsets(
        top: 0,
        leading: 0,
        bottom: 0,
        trailing: 0
    )

    var maxWidth: CGFloat?
    var maxHeight: CGFloat?
    var width: CGFloat?
    var height: CGFloat?
    /// Axes this view may measure past its length on.
    ///
    /// `View.constraints(_:)` uses `width`/`height` as the frame's maximum as well as its length,
    /// which is right for nearly everything but leaves a scroll layout unable to say "take your
    /// percentages of the viewport, but measure as far as you need". Naming the axis lifts the
    /// maximum without disturbing the length, so percentages still resolve against the viewport.
    var uncappedAxes: Axis.Set = []
    var safeAreaInsets: EdgeInsets
    var isHorizontalFixedSize: Bool
    var isVerticalFixedSize: Bool
    var isHorizontalAbsoluteSize: Bool
    var isVerticalAbsoluteSize: Bool
    var aspectRatio: Double?

    init(
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        maxWidth: CGFloat? = nil,
        maxHeight: CGFloat? = nil,
        uncappedAxes: Axis.Set = [],
        isHorizontalFixedSize: Bool = false,
        isVerticalFixedSize: Bool = false,
        isHorizontalAbsoluteSize: Bool = false,
        isVerticalAbsoluteSize: Bool = false,
        aspectRatio: Double? = nil,
        safeAreaInsets: EdgeInsets = emptyEdgeSet
    ) {

        self.width = width
        self.height = height
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        self.uncappedAxes = uncappedAxes
        self.safeAreaInsets = safeAreaInsets
        self.isHorizontalFixedSize = isHorizontalFixedSize
        self.isVerticalFixedSize = isVerticalFixedSize
        self.isHorizontalAbsoluteSize = isHorizontalAbsoluteSize
        self.isVerticalAbsoluteSize = isVerticalAbsoluteSize
        self.aspectRatio = aspectRatio
    }

    /// The length the frame should take on each axis: the view's size, unless the axis is
    /// uncapped, where the frame takes nothing and the length serves only as the reference percent
    /// children resolve against.
    var frameWidth: CGFloat? { uncappedAxes.contains(.horizontal) ? nil : width }
    var frameHeight: CGFloat? { uncappedAxes.contains(.vertical) ? nil : height }

    init(size: CGSize, safeAreaInsets: EdgeInsets) {
        self.init(
            width: size.width + safeAreaInsets.trailing + safeAreaInsets.leading,
            height: size.height + safeAreaInsets.top + safeAreaInsets.bottom,
            isHorizontalFixedSize: true,
            isVerticalFixedSize: true,
            isHorizontalAbsoluteSize: true,
            isVerticalAbsoluteSize: true,
            safeAreaInsets: safeAreaInsets
        )
    }

    /// Resolves a declared size against its parent.
    ///
    /// A percentage covers the space the item occupies, margins included, so they come out of its
    /// share rather than being charged on top: two 50% items with margins fill their parent exactly
    /// instead of overflowing it by their margins. Points and auto are unaffected.
    private static func resolve(
        _ constraint: ThomasSizeConstraint?,
        parent: CGFloat?,
        margins: CGFloat
    ) -> CGFloat? {
        guard let constraint, let value = constraint.calculateSize(parent) else { return nil }
        guard constraint.isPercent, let parent else { return value }
        return max(0, min(value, parent) - margins)
    }

    func contentConstraints(
        _ constrainedSize: ThomasConstrainedSize,
        contentSize: CGSize?,
        margin: ThomasMargin?
    ) -> ViewConstraints {

        let verticalMargins: CGFloat = margin?.verticalMargins ?? 0.0
        let horizontalMargins: CGFloat = margin?.horizontalMargins ?? 0.0

        let parentWidth: CGFloat? = self.width
        let parentHeight: CGFloat? = self.height

        let childMinWidth = Self.resolve(constrainedSize.minWidth, parent: parentWidth, margins: horizontalMargins)
        let childMaxWidth = Self.resolve(constrainedSize.maxWidth, parent: parentWidth, margins: horizontalMargins)
        var childWidth = Self.resolve(constrainedSize.width, parent: parentWidth, margins: horizontalMargins)

        childWidth = childWidth?.bound(
            minValue: childMinWidth,
            maxValue: childMaxWidth
        )

        let childMinHeight = Self.resolve(constrainedSize.minHeight, parent: parentHeight, margins: verticalMargins)
        let childMaxHeight = Self.resolve(constrainedSize.maxHeight, parent: parentHeight, margins: verticalMargins)
        var childHeight = Self.resolve(constrainedSize.height, parent: parentHeight, margins: verticalMargins)

        childHeight = childHeight?.bound(
            minValue: childMinHeight,
            maxValue: childMaxHeight
        )

        let isVerticalFixedSize: Bool = constrainedSize.height.isFixedSize(
            self.isVerticalFixedSize
        )
        let isHorizontalFixedSize: Bool = constrainedSize.width.isFixedSize(
            self.isHorizontalFixedSize
        )
        let isHorizontalAbsoluteSize: Bool = constrainedSize.width.isPoints
        let isVerticalAbsoluteSize: Bool = constrainedSize.height.isPoints

        if let contentSize = contentSize {
            if let maxWidth = childMaxWidth, contentSize.width >= maxWidth {
                childWidth = maxWidth
            } else if let minWidth = childMinWidth,
                contentSize.width <= minWidth
            {
                childWidth = minWidth
            }

            if let maxHeight = childMaxHeight, contentSize.height >= maxHeight {
                childHeight = maxHeight
            } else if let minHeight = childMinHeight,
                contentSize.height <= minHeight
            {
                childHeight = minHeight
            }
        }

        var aspectRatio: Double? = nil
        if let ratio = constrainedSize.aspectRatio, ratio > 0 {
            switch (childWidth, childHeight) {
            case (nil, let h?):
                childWidth = (h * ratio).bound(minValue: childMinWidth, maxValue: childMaxWidth)
                aspectRatio = ratio
            case (let w?, nil):
                childHeight = (w / ratio).bound(minValue: childMinHeight, maxValue: childMaxHeight)
                aspectRatio = ratio
            case (nil, nil):
                aspectRatio = ratio
            default:
                break
            }
        }

        let roundedWidth = childWidth?.rounded()
        let roundedHeight = childHeight?.rounded()

        return ViewConstraints(
            width: roundedWidth,
            height: roundedHeight,
            maxWidth: roundedWidth ?? parentWidth,
            maxHeight: roundedHeight ?? parentHeight,
            isHorizontalFixedSize: isHorizontalFixedSize,
            isVerticalFixedSize: isVerticalFixedSize,
            isHorizontalAbsoluteSize: isHorizontalAbsoluteSize,
            isVerticalAbsoluteSize: isVerticalAbsoluteSize,
            aspectRatio: aspectRatio,
            safeAreaInsets: self.safeAreaInsets
        )
    }

    func childConstraints(
        _ size: ThomasSize,
        margin: ThomasMargin?,
        padding: Double = 0,
        safeAreaInsetsMode: SafeAreaInsetsMode = .ignore
    ) -> ViewConstraints {

        let parentWidth: CGFloat? = self.width?.subtract(padding * 2)
        let parentHeight: CGFloat? = self.height?.subtract(padding * 2)

        var horizontalMargins: CGFloat = margin?.horizontalMargins ?? 0.0
        var verticalMargins: CGFloat = margin?.verticalMargins ?? 0.0

        var safeAreaInsets: EdgeInsets = self.safeAreaInsets
        switch safeAreaInsetsMode {
        case .ignore:
            break
        case .consume:
            safeAreaInsets = ViewConstraints.emptyEdgeSet
        case .consumeMargin:
            horizontalMargins =
                horizontalMargins + self.safeAreaInsets.leading
                + self.safeAreaInsets.trailing
            verticalMargins =
                verticalMargins + self.safeAreaInsets.top
                + self.safeAreaInsets.bottom
            safeAreaInsets = ViewConstraints.emptyEdgeSet
        }

        var childWidth = Self.resolve(size.width, parent: parentWidth, margins: horizontalMargins)
        var childHeight = Self.resolve(size.height, parent: parentHeight, margins: verticalMargins)

        // Pre-compute derived dimension so children receive concrete parent bounds.
        // Also carry the ratio through to ViewConstraints so the .constraints()
        // modifier can apply SwiftUI's .aspectRatio(.fit), which correctly enforces
        // the ratio during the layout pass (handles VStack fair-sharing, nil proposals,
        // landscape orientation, etc.).
        var aspectRatio: Double? = nil
        if let ratio = size.aspectRatio, ratio > 0 {
            switch (childWidth, childHeight) {
            case (nil, let h?):
                // width is auto: derive from height and carry ratio for SwiftUI
                childWidth = h * ratio
                aspectRatio = ratio
            case (let w?, nil):
                // height is auto: derive from width and carry ratio for SwiftUI
                childHeight = w / ratio
                aspectRatio = ratio
            case (nil, nil):
                // Both auto: content determines the size, maxWidth/maxHeight bound it.
                // Don't pre-compute — leave nil so SwiftUI sizes to content.
                // .aspectRatio() on the view enforces the ratio within those bounds.
                aspectRatio = ratio
            default:
                break  // both dims already concrete: explicit values win, ratio ignored
            }
        }

        let isVerticalFixedSize: Bool = size.height.isFixedSize(self.isVerticalFixedSize)
        let isHorizontalFixedSize: Bool = size.width.isFixedSize(self.isHorizontalFixedSize)
        let isHorizontalAbsoluteSize: Bool = size.width.isPoints
        let isVerticalAbsoluteSize: Bool = size.height.isPoints

        var maxWidth = (parentWidth ?? self.maxWidth?.subtract(padding * 2))?.subtract(horizontalMargins)
        var maxHeight = (parentHeight ?? self.maxHeight?.subtract(padding * 2))?.subtract(verticalMargins)

        // For both-auto + aspect_ratio, tighten max bounds by the ratio so children
        // receive accurate parent bounds (e.g. maxHeight 600 with 16:9 ratio → 225, not 600).
        if childWidth == nil, childHeight == nil, let ratio = aspectRatio, ratio > 0 {
            switch (maxWidth, maxHeight) {
            case (let w?, let h?):
                maxWidth = min(w, h * ratio)
                maxHeight = min(h, w / ratio)
            case (let w?, nil):
                maxHeight = w / ratio
            case (nil, let h?):
                maxWidth = h * ratio
            case (nil, nil):
                break
            }
        }

        return ViewConstraints(
            width: childWidth,
            height: childHeight,
            maxWidth: childWidth ?? maxWidth,
            maxHeight: childHeight ?? maxHeight,
            // Not inherited: a child gets its own length from us, so it is capped by that.
            // Only the view a scroll layout hands its constraints to may exceed its length.
            uncappedAxes: [],
            isHorizontalFixedSize: isHorizontalFixedSize,
            isVerticalFixedSize: isVerticalFixedSize,
            isHorizontalAbsoluteSize: isHorizontalAbsoluteSize,
            isVerticalAbsoluteSize: isVerticalAbsoluteSize,
            aspectRatio: aspectRatio,
            safeAreaInsets: safeAreaInsets
        )
    }
}

extension ViewConstraints {
    /// Returns a copy of these constraints with nil (auto) dimensions replaced by the
    /// measured values.  Concrete dimensions are left unchanged, and isFixedSize flags
    /// are not touched — the fill is a hint for percent-child calculations only, not a
    /// hard layout constraint on the parent.
    func fillingMeasured(width: CGFloat?, height: CGFloat?) -> ViewConstraints {
        var copy = self
        if copy.width == nil { copy.width = width }
        if copy.height == nil { copy.height = height }
        return copy
    }
}

extension ThomasSizeConstraint {
    func calculateSize(_ parentSize: CGFloat?) -> CGFloat? {
        switch self {
        case .points(let points):
            return points
        case .percent(let percent):
            guard let parentSize = parentSize else {
                return nil
            }
            return percent / 100.0 * parentSize
        case .auto:
            return nil
        }
    }

    func isFixedSize(_ isParentFixed: Bool) -> Bool {
        switch self {
        case .points(_):
            return true
        case .percent(_):
            return isParentFixed
        case .auto:
            return false
        }
    }

    var isAuto: Bool {
        switch self {
        case .points(_):
            return false
        case .percent(_):
            return false
        case .auto:
            return true
        }
    }

    var isPercent: Bool {
        switch self {
        case .points(_):
            return false
        case .percent(_):
            return true
        case .auto:
            return false
        }
    }

    var isPoints: Bool {
        if case .points = self { return true }
        return false
    }
}

extension ThomasMargin {
    var verticalMargins: CGFloat {
        return (self.bottom ?? 0.0) + (self.top ?? 0.0)
    }

    var horizontalMargins: CGFloat {
        return (self.start ?? 0.0) + (self.end ?? 0.0)
    }
}

extension CGFloat {
    func subtract(_ value: CGFloat) -> CGFloat {
        return self - value
    }

    func bound(minValue: CGFloat? = nil, maxValue: CGFloat? = nil) -> CGFloat {
        var value = self
        if let minValue = minValue {
            value = CGFloat.maximum(value, minValue)
        }

        if let maxValue = maxValue {
            value = CGFloat.minimum(value, maxValue)
        }

        return value
    }

    /// Returns self if finite, otherwise returns nil.
    /// Guards against NaN and infinity crashing SwiftUI frame/offset/position modifiers.
    var safeValue: CGFloat? {
        self.isFinite ? self : nil
    }
}
