/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0, tvOS 13.0, *)
struct ViewConstraints: Equatable {

    enum SafeAreaInsetsMode {
        // Insets will be passed on to children
        case ignore

        // Insets will be consumed
        case consume

        // Insets will be consumed and applied as margins if the size is percent
        case consumeMargin
    }

    static let emptyEdgeSet = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)

    var width: CGFloat?
    var height: CGFloat?
    var safeAreaInsets: EdgeInsets
    var isHorizontalFixedSize: Bool
    var isVerticalFixedSize: Bool

    init(width: CGFloat? = nil,
         height: CGFloat? = nil,
         isHorizontalFixedSize: Bool = false,
         isVerticalFixedSize: Bool = false,
         safeAreaInsets: EdgeInsets = emptyEdgeSet) {

        self.width = width
        self.height = height
        self.safeAreaInsets = safeAreaInsets
        self.isHorizontalFixedSize = isHorizontalFixedSize
        self.isVerticalFixedSize = isVerticalFixedSize
    }

    init(size: CGSize, safeAreaInsets: EdgeInsets) {
        self.init(width: size.width + safeAreaInsets.trailing + safeAreaInsets.leading,
                  height: size.height + safeAreaInsets.top + safeAreaInsets.bottom,
                  isHorizontalFixedSize: true,
                  isVerticalFixedSize: true,
                  safeAreaInsets: safeAreaInsets)
    }

    func contentConstraints(_ constrainedSize: ConstrainedSize,
                            contentSize: CGSize?,
                            margin: Margin?) -> ViewConstraints {

        let verticalMargins = (margin?.top ?? 0) + (margin?.bottom ?? 0)
        let horizontalMargins = (margin?.start ?? 0) + (margin?.end ?? 0)

        let parentWidth = self.width?.subtract(horizontalMargins)
        let parentHeight = self.height?.subtract(verticalMargins)

        let childMinWidth = constrainedSize.minWidth?.calculateSize(parentWidth)
        let childMaxWidth = constrainedSize.maxWidth?.calculateSize(parentWidth)
        var childWidth = constrainedSize.width.calculateSize(parentWidth)
        childWidth = childWidth?.bound(minValue: childMinWidth, maxValue: childMaxWidth)

        let childMinHeight = constrainedSize.minHeight?.calculateSize(parentHeight)
        let childMaxHeight = constrainedSize.maxHeight?.calculateSize(parentHeight)
        var childHeight = constrainedSize.height.calculateSize(parentHeight)
        childHeight = childHeight?.bound(minValue: childMinHeight, maxValue: childMaxHeight)

        let isVerticalFixedSize = constrainedSize.height.isFixedSize(self.isVerticalFixedSize)
        let isHorizontalFixedSize = constrainedSize.width.isFixedSize(self.isHorizontalFixedSize)

        if let contentSize = contentSize {
            if let maxWidth = childMaxWidth, contentSize.width >= maxWidth {
                childWidth = maxWidth
            } else if let minWidth = childMinWidth, contentSize.width <= minWidth {
                childWidth = minWidth
            }

            if let maxHeight = childMaxHeight, contentSize.height >= maxHeight {
                childHeight = maxHeight
            } else if let minHeight = childMinHeight, contentSize.height <= minHeight {
                childHeight = minHeight
            }
        }

        return ViewConstraints(width: childWidth,
                               height: childHeight,
                               isHorizontalFixedSize: isHorizontalFixedSize,
                               isVerticalFixedSize: isVerticalFixedSize,
                               safeAreaInsets: self.safeAreaInsets)
    }


    func childConstraints(_ size: Size,
                          margin: Margin?,
                          padding: Double = 0,
                          safeAreaInsetsMode: SafeAreaInsetsMode = .ignore) -> ViewConstraints {

        let parentWidth = self.width?.subtract(padding * 2)
        let parentHeight = self.height?.subtract(padding * 2)

        var horizontalMargins = (margin?.start ?? 0) + (margin?.end ?? 0)
        var verticalMargins = (margin?.top ?? 0) + (margin?.bottom ?? 0)

        var safeAreaInsets = self.safeAreaInsets
        switch(safeAreaInsetsMode) {
        case .ignore:
            break
        case .consume:
            safeAreaInsets = ViewConstraints.emptyEdgeSet
        case .consumeMargin:
            horizontalMargins = horizontalMargins + self.safeAreaInsets.leading + self.safeAreaInsets.trailing
            verticalMargins = verticalMargins + self.safeAreaInsets.top + self.safeAreaInsets.bottom
            safeAreaInsets = ViewConstraints.emptyEdgeSet
        }

        var childWidth = size.width.calculateSize(parentWidth)
        var childHeight = size.height.calculateSize(parentHeight)

        if size.width.isPercent(), let width = childWidth, let parentWidth = parentWidth {
            childWidth = min(width, parentWidth.subtract(horizontalMargins))
        }

        if size.height.isPercent(), let height = childHeight, let parentHeight = parentHeight {
            childHeight = min(height, parentHeight.subtract(verticalMargins))
        }

        let isVerticalFixedSize = size.height.isFixedSize(self.isVerticalFixedSize)
        let isHorizontalFixedSize = size.width.isFixedSize(self.isHorizontalFixedSize)

        return ViewConstraints(width: childWidth,
                               height: childHeight,
                               isHorizontalFixedSize: isHorizontalFixedSize,
                               isVerticalFixedSize: isVerticalFixedSize,
                               safeAreaInsets: safeAreaInsets)
    }
}

extension SizeConstraint {
    func calculateSize(_ parentSize: CGFloat?) -> CGFloat? {
        switch (self) {
        case .points(let points):
            return points
        case .percent(let percent):
            guard let parentSize = parentSize else {
                return nil
            }
            return percent/100.0 * parentSize
        case.auto:
            return nil
        }
    }

    func isFixedSize(_ isParentFixed: Bool) -> Bool {
        switch (self) {
        case .points(_):
            return true
        case .percent(_):
            return isParentFixed
        case.auto:
            return false
        }
    }

    func isPercent() -> Bool {
        switch (self) {
        case .points(_):
            return false
        case .percent(_):
            return true
        case.auto:
            return false
        }
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
