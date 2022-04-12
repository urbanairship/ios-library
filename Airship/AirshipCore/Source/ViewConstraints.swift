/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0, tvOS 13.0, *)
struct ViewConstraints: Equatable {

    static let emptyEdgeSet = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)

    var width: CGFloat?
    var height: CGFloat?
    var safeAreaInsets: EdgeInsets

    init(width: CGFloat? = nil, height: CGFloat? = nil, safeAreaInsets: EdgeInsets) {
        self.width = width
        self.height = height
        self.safeAreaInsets = safeAreaInsets
    }
    
    static func containerConstraints(_ size: CGSize,
                                     safeAreaInsets: EdgeInsets,
                                     ignoreSafeArea: Bool) -> ViewConstraints {
        var width = size.width
        var height = size.height
        
        if (ignoreSafeArea) {
            width += safeAreaInsets.trailing + safeAreaInsets.leading
            height += safeAreaInsets.top + safeAreaInsets.bottom
            return ViewConstraints(width: width,
                                   height: height,
                                   safeAreaInsets: safeAreaInsets)
        } else {
            return ViewConstraints(width: width,
                                   height: height,
                                   safeAreaInsets: emptyEdgeSet)
        }
    }


    func calculateChild(_ constrainedSize: ConstrainedSize,
                       contentSize: CGSize?,
                       margin: Margin?,
                       ignoreSafeArea: Bool? = nil) -> ViewConstraints {

        let horizontalInsets = self.safeAreaInsets.leading + self.safeAreaInsets.trailing
        let verticalInsets = self.safeAreaInsets.top + self.safeAreaInsets.bottom

        let verticalMargins = (margin?.top ?? 0) + (margin?.bottom ?? 0) as CGFloat
        let horizontalMargins = (margin?.start ?? 0) + (margin?.end ?? 0) as CGFloat

        var parentWidth = self.width
        var parentHeight = self.height

        parentWidth = parentWidth?.subtract(horizontalMargins)
        parentHeight = parentHeight?.subtract(verticalMargins)

        var insets = self.safeAreaInsets

        if (ignoreSafeArea != true) {
            parentWidth = parentWidth?.subtract(horizontalInsets)
            parentHeight = parentHeight?.subtract(verticalInsets)
            insets = ViewConstraints.emptyEdgeSet
        }

        let childMinWidth = constrainedSize.minWidth?.calculateSize(parentWidth)
        let childMaxWidth = constrainedSize.maxWidth?.calculateSize(parentWidth)
        var childWidth = constrainedSize.width.calculateSize(parentWidth)
        childWidth = childWidth?.bound(minValue: childMinWidth, maxValue: childMaxWidth)

        let childMinHeight = constrainedSize.minHeight?.calculateSize(parentHeight)
        let childMaxHeight = constrainedSize.maxHeight?.calculateSize(parentHeight)
        var childHeight = constrainedSize.height.calculateSize(parentHeight)
        childHeight = childHeight?.bound(minValue: childMinHeight, maxValue: childMaxHeight)

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

        return ViewConstraints(width: childWidth, height: childHeight, safeAreaInsets: insets)
    }

    func calculateChild(_ childSize: Size,
                        margin: Margin? = nil,
                        ignoreSafeArea: Bool? = nil) -> ViewConstraints {
        let horizontalInsets = self.safeAreaInsets.leading + self.safeAreaInsets.trailing
        let verticalInsets = self.safeAreaInsets.top + self.safeAreaInsets.bottom

        var parentWidth = self.width
        var parentHeight = self.height

        if (margin != nil) {
            let verticalMargins = (margin?.top ?? 0) + (margin?.bottom ?? 0)
            let horizontalMargins = (margin?.start ?? 0) + (margin?.end ?? 0)

            parentWidth = parentWidth?.subtract(horizontalMargins)
            parentHeight = parentHeight?.subtract(verticalMargins)
        }
        
        var insets = self.safeAreaInsets
        
        if (ignoreSafeArea != true) {
            parentWidth = parentWidth?.subtract(horizontalInsets)
            parentHeight = parentHeight?.subtract(verticalInsets)
            insets = ViewConstraints.emptyEdgeSet
        }

        let childWidth = childSize.width.calculateSize(parentWidth)
        let childHeight = childSize.height.calculateSize(parentHeight)

        return ViewConstraints(width: childWidth,
                               height: childHeight,
                               safeAreaInsets: insets)
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
}

private extension CGFloat {
    func subtract(_ value: CGFloat) -> CGFloat {
        return self - value
    }

    func bound(minValue: CGFloat?, maxValue: CGFloat?) -> CGFloat {
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

