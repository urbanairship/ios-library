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
    /// A floor the view may not shrink below, and which it may grow past.
    ///
    /// The counterpart to `maxWidth`/`maxHeight`, and the only part of a declared size that can be
    /// handed down before anything has been measured: `min_height: 80%` is a share of the window,
    /// settled the moment the window is known, where an `auto` length is settled by the content and
    /// so cannot be. Without somewhere to put it a modal could only apply its floor as a frame
    /// around its content, outside the layout, where nothing inside could see it — a background at
    /// `100%` filled the content it was behind rather than the modal it was in.
    ///
    /// A minimum bounds without capping, so a floor never stops content growing past it: an auto
    /// item still sets the length, and `100%` beside it still follows.
    var minWidth: CGFloat?
    var minHeight: CGFloat?
    var width: CGFloat?
    var height: CGFloat?
    /// Axes this view may measure past its length on.
    ///
    /// `View.constraints(_:)` uses `width`/`height` as the frame's maximum as well as its length,
    /// which is right for nearly everything but leaves a scroll layout unable to say "take your
    /// percentages of the viewport, but measure as far as you need". Naming the axis lifts the
    /// maximum without disturbing the length, so percentages still resolve against the viewport.
    var uncappedAxes: Axis.Set = []
    /// Axes whose length came from measuring a view rather than from a constraint.
    ///
    /// A length usually states what a view was given. `fillingMeasured` writes one that says what
    /// a view turned out to be, and anything derived from it — a child's percentage, the `maxHeight`
    /// a child inherits — carries that measurement inside it. Most of the layout can't tell the
    /// difference and doesn't need to, but a stack solving for its own length must: a bound that
    /// already contains the stack is circular, and feeding it back diverges. Inherited by children,
    /// since a length derived from a measured one is measured too.
    var measuredAxes: Axis.Set = []
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
        minWidth: CGFloat? = nil,
        minHeight: CGFloat? = nil,
        uncappedAxes: Axis.Set = [],
        measuredAxes: Axis.Set = [],
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
        self.minWidth = minWidth
        self.minHeight = minHeight
        self.uncappedAxes = uncappedAxes
        self.measuredAxes = measuredAxes
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
    /// `safeValue` because these reach `.frame(idealWidth:maxWidth:…)` directly: a non-finite
    /// length there is an invalid frame dimension, and an unset one is merely auto.
    var frameWidth: CGFloat? { uncappedAxes.contains(.horizontal) ? nil : width?.safeValue }
    var frameHeight: CGFloat? { uncappedAxes.contains(.vertical) ? nil : height?.safeValue }

    /// The floor the frame should take, on the same terms: nothing on an uncapped axis, where the
    /// view is being asked to measure freely and a floor would be one more thing holding it open.
    var frameMinWidth: CGFloat? { uncappedAxes.contains(.horizontal) ? nil : minWidth?.safeValue }
    var frameMinHeight: CGFloat? { uncappedAxes.contains(.vertical) ? nil : minHeight?.safeValue }

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

    /// A child's share of a floor its parent is holding, for a child that asked for a share.
    ///
    /// Margins come out of it for the same reason they come out of a percentage's length: the share
    /// covers the space the item occupies, margins included.
    private static func resolvedMinimum(
        _ constraint: ThomasSizeConstraint,
        parentMin: CGFloat?,
        margins: CGFloat
    ) -> CGFloat? {
        guard let parentMin, case .percent(let percent) = constraint else { return nil }
        return max(0, (percent / 100.0 * parentMin) - margins)
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

        // Rounded where they are resolved, because a bound is compared against a measurement and
        // then handed back as a length — and the length that leaves here is rounded. A percentage
        // that lands on a fraction made those two different numbers: content measured at the
        // rounded 455 was tested against 455.4, failed, and the clamp let go; the content grew back
        // to its natural height, exceeded the bound, and clamped again, every pass, forever. Which
        // way the fraction has to fall differs by direction — under .5 for a maximum, over it for a
        // minimum — so both are rounded rather than the comparison being patched.
        let childMinWidth = Self.resolve(constrainedSize.minWidth, parent: parentWidth, margins: horizontalMargins)?.rounded()
        let childMaxWidth = Self.resolve(constrainedSize.maxWidth, parent: parentWidth, margins: horizontalMargins)?.rounded()
        var childWidth = Self.resolve(constrainedSize.width, parent: parentWidth, margins: horizontalMargins)

        childWidth = childWidth?.bound(
            minValue: childMinWidth,
            maxValue: childMaxWidth
        )

        let childMinHeight = Self.resolve(constrainedSize.minHeight, parent: parentHeight, margins: verticalMargins)?.rounded()
        let childMaxHeight = Self.resolve(constrainedSize.maxHeight, parent: parentHeight, margins: verticalMargins)?.rounded()
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

        // A maximum has to become the length, because a length is the only thing that caps a view.
        // A minimum does not, and must not: it travels as a floor instead. Written into the length
        // it would decide whether the view was still short, having just made it taller — the walk
        // between hugging and the floor that the modal used to unpick by discarding the length
        // altogether, taking the floor with it.
        if let contentSize = contentSize {
            if let maxWidth = childMaxWidth, contentSize.width >= maxWidth {
                childWidth = maxWidth
            }

            if let maxHeight = childMaxHeight, contentSize.height >= maxHeight {
                childHeight = maxHeight
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
            // Only where there is no length to hold the view open. A length has already been bound
            // by the floor above, so repeating it would say nothing.
            minWidth: roundedWidth == nil ? childMinWidth?.bound(maxValue: childMaxWidth) : nil,
            minHeight: roundedHeight == nil ? childMinHeight?.bound(maxValue: childMaxHeight) : nil,
            isHorizontalFixedSize: isHorizontalFixedSize,
            isVerticalFixedSize: isVerticalFixedSize,
            isHorizontalAbsoluteSize: isHorizontalAbsoluteSize,
            isVerticalAbsoluteSize: isVerticalAbsoluteSize,
            aspectRatio: aspectRatio,
            safeAreaInsets: self.safeAreaInsets
        )
    }

    /// [borderStrokeWidth] is the child's own stroke, not ours.
    ///
    /// A declared length is the whole footprint the author asked for, and the border is drawn inside
    /// it — so the frame the child sizes to is that length less the stroke on both edges, and the
    /// padding the border modifier adds around it brings the footprint back to what was declared.
    /// Left out, the padding landed outside a frame already set to the full length and the view came
    /// out `2 x stroke` bigger than it said it was.
    ///
    /// This is also why nothing subtracts the stroke a second time when that child goes on to size
    /// children of its own: its length is already the content box by then.
    /// A copy with [view]'s own stroke taken out of whatever lengths are set.
    ///
    /// `childConstraints` does this for anything a container or a stack sizes, which is nearly
    /// everything. A placement root has no such parent — its length comes from the placement — so it
    /// asks for the same treatment here, and a bordered root card stays the size it was placed at.
    func deductingBorder(of view: ThomasViewInfo) -> ViewConstraints {
        let stroke = CGFloat(view.borderStrokeWidth * 2)
        guard stroke > 0 else { return self }

        var copy = self
        copy.width = copy.width.map { max(0, $0 - stroke) }
        copy.height = copy.height.map { max(0, $0 - stroke) }
        return copy
    }

    func childConstraints(
        _ size: ThomasSize,
        margin: ThomasMargin?,
        borderStrokeWidth: Double = 0,
        safeAreaInsetsMode: SafeAreaInsetsMode = .ignore
    ) -> ViewConstraints {

        let parentWidth: CGFloat? = self.width
        let parentHeight: CGFloat? = self.height

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

        // A floor descends the way a length does: through percentages, and only through them. A
        // child that asks for the whole of a parent that will be at least this tall will itself be
        // at least this tall, and half of it asks for half. Anything else keeps its own size — an
        // item with a length has one already, and an `auto` item is sized by what is inside it,
        // which a floor from above has no business holding open.
        let childMinWidth = Self.resolvedMinimum(size.width, parentMin: minWidth, margins: horizontalMargins)
        let childMinHeight = Self.resolvedMinimum(size.height, parentMin: minHeight, margins: verticalMargins)

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

        var maxWidth = (parentWidth ?? self.maxWidth)?.subtract(horizontalMargins)
        var maxHeight = (parentHeight ?? self.maxHeight)?.subtract(verticalMargins)

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

        // The child's own stroke, taken out of a length it was given and only out of a length: an
        // auto axis has no footprint to fit a border inside, so there the border grows the view and
        // that is the right answer. Clamped, since a stroke wider than the length it sits in would
        // otherwise give a negative frame.
        //
        // After the ratio, not before. The ratio describes the box the author sees, which is the
        // whole footprint including the border — deriving from an already-reduced length made the
        // visible box off-ratio by the stroke.
        let stroke = CGFloat(borderStrokeWidth * 2)
        if stroke > 0 {
            childWidth = childWidth.map { max(0, $0 - stroke) }
            childHeight = childHeight.map { max(0, $0 - stroke) }
        }

        // Inherited: everything a child gets on this axis is derived from our length, so if ours was
        // measured then so are the child's percentage and the maximum it falls back to.
        //
        // Except where the child declared points. It didn't derive that from us — it is a number
        // the author wrote, and the maximum everything inside it falls back to is that number, a
        // real ceiling. Carrying the mark past it told a stack further down that its ceiling was a
        // measurement, and a stack whose percentages reach 1 gives up its fair share of one of
        // those rather than diverge: `60 + 100% + 100%` in a 200pt box drew 60 and two text-height
        // rows, leaving the rest of the box empty.
        var childMeasuredAxes = measuredAxes
        if isHorizontalAbsoluteSize {
            childMeasuredAxes.remove(.horizontal)
        }
        if isVerticalAbsoluteSize {
            childMeasuredAxes.remove(.vertical)
        }

        return ViewConstraints(
            width: childWidth,
            height: childHeight,
            maxWidth: childWidth ?? maxWidth,
            maxHeight: childHeight ?? maxHeight,
            minWidth: childWidth == nil ? childMinWidth : nil,
            minHeight: childHeight == nil ? childMinHeight : nil,
            // Not inherited: a child gets its own length from us, so it is capped by that.
            // Only the view a scroll layout hands its constraints to may exceed its length.
            uncappedAxes: [],
            measuredAxes: childMeasuredAxes,
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
        if copy.width == nil, let width = width?.safeValue {
            copy.width = width
            copy.measuredAxes.insert(.horizontal)
        }
        if copy.height == nil, let height = height?.safeValue {
            copy.height = height
            copy.measuredAxes.insert(.vertical)
        }
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
