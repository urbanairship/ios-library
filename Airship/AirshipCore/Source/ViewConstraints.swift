/* Copyright Airship and Contributors */

import Foundation

struct ViewConstraints {

    /// Min width
    let minWidth: CGFloat?
    
    /// Ideal width. Nil if the view should size to fit content.
    let width: CGFloat?
    
    /// Min height
    let minHeight: CGFloat?
    
    /// Ideal height. Nil if the view should size to fit content.
    let height: CGFloat?
    
    private static func calculateSize(_ sizeContraints: SizeConstraint?,
                                      parentSize: CGFloat?,
                                      margins: CGFloat) -> CGFloat? {
        
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
            return percent/100.0 * parentSize - margins
        case.auto:
            return nil
        }
    }
    
    static func calculateChildConstraints(childSize: Size,
                                          childMargins: Margin?,
                                          parentConstraints: ViewConstraints) -> ViewConstraints {
        let horizontalMargins = (childMargins?.start ?? 0) + (childMargins?.end ?? 0)
        let verticalMargins = (childMargins?.bottom ?? 0) + (childMargins?.top ?? 0)
        let parentWidth = parentConstraints.width
        let parentHeight = parentConstraints.height
    
        let minWidth = calculateSize(childSize.minWidth, parentSize: parentWidth, margins: horizontalMargins)
        let width = calculateSize(childSize.width, parentSize: parentWidth, margins: horizontalMargins)
        let minHeight = calculateSize(childSize.minHeight, parentSize: parentHeight, margins: verticalMargins)
        let height = calculateSize(childSize.height, parentSize: parentHeight, margins: verticalMargins)
        
        return ViewConstraints(minWidth: minWidth,
                               width: width,
                               minHeight: minHeight,
                               height: height)
        
    }
}
