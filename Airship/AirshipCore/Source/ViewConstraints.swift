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


    func calculateSize(_ constrainedSize: ConstrainedSize, contentSize: CGSize?, ignoreSafeArea: Bool? = nil) -> ViewConstraints {
        let horizontalInsets = self.safeAreaInsets.leading + self.safeAreaInsets.trailing
        let verticalInsets = self.safeAreaInsets.top + self.safeAreaInsets.bottom

        var parentWidth = self.width
        var parentHeight = self.height

        var insets = self.safeAreaInsets

        if (ignoreSafeArea != true) {
            parentWidth = optionalSubtract(value: horizontalInsets, from: parentWidth)
            parentHeight = optionalSubtract(value: verticalInsets, from: parentHeight)
            insets = ViewConstraints.emptyEdgeSet
        }

        let childMinWidth = constrainedSize.minWidth?.calculateSize(parentWidth)
        let childMaxWidth = constrainedSize.maxWidth?.calculateSize(parentWidth)
        var childWidth = constrainedSize.width.calculateSize(parentWidth)
        childWidth = boundConstraint(constraint: childWidth, minValue: childMinWidth, maxValue: childMaxWidth)

        let childMinHeight = constrainedSize.minHeight?.calculateSize(parentHeight)
        let childMaxHeight = constrainedSize.maxHeight?.calculateSize(parentHeight)
        var childHeight = constrainedSize.height.calculateSize(parentHeight)
        childHeight = boundConstraint(constraint: childHeight, minValue: childMinHeight, maxValue: childMaxHeight)

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

    private func boundConstraint(constraint: CGFloat?, minValue: CGFloat?, maxValue: CGFloat?) -> CGFloat? {
        guard var constraint = constraint else {
            return nil
        }

        if let minValue = minValue {
            constraint = max(constraint, minValue)
        }

        if let maxValue = maxValue {
            constraint = min(constraint, maxValue)
        }

        return constraint
    }

    func calculateChild(_ childSize: Size, ignoreSafeArea: Bool? = nil) -> ViewConstraints {
        let horizontalInsets = self.safeAreaInsets.leading + self.safeAreaInsets.trailing
        let verticalInsets = self.safeAreaInsets.top + self.safeAreaInsets.bottom
        
        var parentWidth = self.width
        var parentHeight = self.height
        var insets = self.safeAreaInsets
        
        if (ignoreSafeArea != true) {
            parentWidth = optionalSubtract(value: horizontalInsets, from: parentWidth)
            parentHeight = optionalSubtract(value: verticalInsets, from: parentHeight)
            insets = ViewConstraints.emptyEdgeSet
        }

        let childWidth = ViewConstraints.calculateSize(childSize.width, parentSize: parentWidth)
        let childHeight = ViewConstraints.calculateSize(childSize.height, parentSize: parentHeight)

        return ViewConstraints(width: childWidth,
                               height: childHeight,
                               safeAreaInsets: insets)
    }
    
    private func optionalSubtract(value: CGFloat, from: CGFloat?) -> CGFloat? {
        guard let from = from else {
            return nil
        }
        
        return from - value
    }

    private static func calculateSize(_ sizeContraints: SizeConstraint?,
                                      parentSize: CGFloat?) -> CGFloat? {
        
        guard let constraint = sizeContraints else {
            return nil
        }
        
        switch (constraint) {
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
