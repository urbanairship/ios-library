/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0, tvOS 13.0, *)
struct ViewConstraints: Equatable {

    static let emptyEdgeSet = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
    
    // widths
    var minWidth: CGFloat?
    var width: CGFloat?
    var maxWidth: CGFloat?

    // heights
    var minHeight: CGFloat?
    var height: CGFloat?
    var maxHeight: CGFloat?
    
    // Safe area insets
    var safeAreaInsets: EdgeInsets

    init(minWidth: CGFloat? = nil, width: CGFloat? = nil, maxWidth: CGFloat? = nil,
         minHeight: CGFloat? = nil, height: CGFloat? = nil, maxHeight: CGFloat? = nil,
         safeAreaInsets: EdgeInsets) {
        self.minWidth = minWidth
        self.width = width
        self.maxWidth = maxWidth
        self.minHeight = minHeight
        self.height = height
        self.maxHeight = maxHeight
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

    
    func calculateChild(_ childSize: Size, ignoreSafeArea: Bool? = nil) -> ViewConstraints {
        let horizontalInsets = self.safeAreaInsets.leading + self.safeAreaInsets.trailing
        let verticalInsets = self.safeAreaInsets.top + self.safeAreaInsets.bottom
        
        var parentMinWidth = self.minWidth
        var parentWidth = self.width
        var parentMaxWidth = self.maxWidth
        
        var parentMinHeight = self.minHeight
        var parentHeight = self.height
        var parentMaxHeight = self.maxHeight
        
        var insets = self.safeAreaInsets
        
        if (ignoreSafeArea != true) {
            parentMinWidth = optionalSubtract(value: horizontalInsets, from: parentMinWidth)
            parentWidth = optionalSubtract(value: horizontalInsets, from: parentWidth)
            parentMaxWidth = optionalSubtract(value: horizontalInsets, from: parentMaxWidth)
            parentMinHeight = optionalSubtract(value: verticalInsets, from: parentMinHeight)
            parentHeight = optionalSubtract(value: verticalInsets, from: parentHeight)
            parentMaxHeight = optionalSubtract(value: verticalInsets, from: parentMaxHeight)
            insets = ViewConstraints.emptyEdgeSet
        }
        
        let childMinWidth = ViewConstraints.calculateSize(childSize.minWidth, parentSize: parentMinWidth ?? parentWidth)
        let childMaxWidth = ViewConstraints.calculateSize(childSize.maxWidth, parentSize: parentMaxWidth ?? parentWidth)
        var childWidth = ViewConstraints.calculateSize(childSize.width, parentSize: parentWidth)
        childWidth = boundConstraint(constraint: childWidth, minValue: childMinWidth, maxValue: childMaxWidth)

        let childMinHeight = ViewConstraints.calculateSize(childSize.minHeight, parentSize: parentMinHeight ?? parentHeight)
        let childMaxHeight = ViewConstraints.calculateSize(childSize.maxHeight, parentSize: parentMaxHeight ?? parentHeight)
        var childHeight = ViewConstraints.calculateSize(childSize.height, parentSize: parentHeight)
        childHeight = boundConstraint(constraint: childHeight, minValue: childMinHeight, maxValue: childMaxHeight)
        
        return ViewConstraints(minWidth: childMinWidth,
                               width: childWidth,
                               maxWidth: childMaxWidth,
                               minHeight: childMinHeight,
                               height: childHeight,
                               maxHeight: childMaxHeight,
                               safeAreaInsets: insets)
    }
    
    private func optionalSubtract(value: CGFloat, from: CGFloat?) -> CGFloat? {
        guard let from = from else {
            return nil
        }
        
        return from - value
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
