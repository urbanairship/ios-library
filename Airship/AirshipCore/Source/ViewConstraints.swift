/* Copyright Airship and Contributors */


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

    static let emptyEdgeSet = EdgeInsets(
        top: 0,
        leading: 0,
        bottom: 0,
        trailing: 0
    )

    var maxWidth: CGFloat?
    var maxHeight: CGFloat?
    var width: CGFloat?
    var height: CGFloat?
    var safeAreaInsets: EdgeInsets
    var isHorizontalFixedSize: Bool
    var isVerticalFixedSize: Bool

    init(
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        maxWidth: CGFloat? = nil,
        maxHeight: CGFloat? = nil,
        isHorizontalFixedSize: Bool = false,
        isVerticalFixedSize: Bool = false,
        safeAreaInsets: EdgeInsets = emptyEdgeSet
    ) {

        self.width = width
        self.height = height
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        self.safeAreaInsets = safeAreaInsets
        self.isHorizontalFixedSize = isHorizontalFixedSize
        self.isVerticalFixedSize = isVerticalFixedSize
    }

    init(size: CGSize, safeAreaInsets: EdgeInsets) {
        self.init(
            width: size.width + safeAreaInsets.trailing + safeAreaInsets.leading,
            height: size.height + safeAreaInsets.top + safeAreaInsets.bottom,
            isHorizontalFixedSize: true,
            isVerticalFixedSize: true,
            safeAreaInsets: safeAreaInsets
        )
    }

    func contentConstraints(
        _ constrainedSize: ThomasConstrainedSize,
        contentSize: CGSize?,
        margin: ThomasMargin?
    ) -> ViewConstraints {

        let verticalMargins: CGFloat = margin?.verticalMargins ?? 0.0
        let horizontalMargins: CGFloat = margin?.horiztonalMargins ?? 0.0

        let parentWidth: CGFloat? = self.width?.subtract(horizontalMargins)
        let parentHeight: CGFloat? = self.height?.subtract(verticalMargins)

        let childMinWidth: CGFloat? = constrainedSize.minWidth?.calculateSize(
            parentWidth
        )

        let childMaxWidth: CGFloat? = constrainedSize.maxWidth?.calculateSize(
            parentWidth
        )

        var childWidth: CGFloat? = constrainedSize.width.calculateSize(
            parentWidth
        )

        childWidth = childWidth?.bound(
            minValue: childMinWidth,
            maxValue: childMaxWidth
        )

        let childMinHeight: CGFloat? = constrainedSize.minHeight?.calculateSize(
            parentHeight
        )
        let childMaxHeight: CGFloat? = constrainedSize.maxHeight?.calculateSize(
            parentHeight
        )

        var childHeight: CGFloat? = constrainedSize.height.calculateSize(
            parentHeight
        )

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

        return ViewConstraints(
            width: childWidth,
            height: childHeight,
            maxWidth: childWidth ?? parentWidth,
            maxHeight: childHeight ?? parentHeight,
            isHorizontalFixedSize: isHorizontalFixedSize,
            isVerticalFixedSize: isVerticalFixedSize,
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

        var horizontalMargins: CGFloat = margin?.horiztonalMargins ?? 0.0
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

        var childWidth: CGFloat? = size.width.calculateSize(parentWidth)
        var childHeight: CGFloat? = size.height.calculateSize(parentHeight)

        if size.width.isPercent, let width = childWidth, let parentWidth = parentWidth {
            childWidth = max(0, min(width, parentWidth.subtract(horizontalMargins)))
        }

        if size.height.isPercent, let height = childHeight, let parentHeight = parentHeight {
            childHeight = max(0, min(height, parentHeight.subtract(verticalMargins)))
        }

        let isVerticalFixedSize: Bool = size.height.isFixedSize(
            self.isVerticalFixedSize
        )

        let isHorizontalFixedSize: Bool = size.width.isFixedSize(
            self.isHorizontalFixedSize
        )

        let maxWidth = (parentWidth ?? self.maxWidth?.subtract(padding * 2))?.subtract(horizontalMargins)
        let maxHeight = (parentHeight ?? self.maxHeight?.subtract(padding * 2))?.subtract(verticalMargins)

        return ViewConstraints(
            width: childWidth,
            height: childHeight,
            maxWidth: childWidth ?? maxWidth,
            maxHeight: childHeight ?? maxHeight,
            isHorizontalFixedSize: isHorizontalFixedSize,
            isVerticalFixedSize: isVerticalFixedSize,
            safeAreaInsets: safeAreaInsets
        )
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
}

extension ThomasMargin {
    var verticalMargins: CGFloat {
        return (self.bottom ?? 0.0) + (self.top ?? 0.0)
    }

    var horiztonalMargins: CGFloat {
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
}
