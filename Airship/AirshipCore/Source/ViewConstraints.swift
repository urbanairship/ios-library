/* Copyright Airship and Contributors */

import Foundation

struct ViewConstraints {

    /// Ideal width. Nil if the view should size to fit content.
    let width: CGFloat?

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
            return points + margins
        case .percent(let percent):
            guard let parentSize = parentSize else {
                return nil
            }
            return min(percent/100.0 * parentSize + margins, parentSize)
        case.auto:
            return nil
        }
    }
    
    
    static func calculateChildConstraints(childSize: Size,
                                          parentConstraints: ViewConstraints,
                                          childMargins: Margin? = nil) -> ViewConstraints {
        let horizontalMargins = (childMargins?.start ?? 0) + (childMargins?.end ?? 0)
        let verticalMargins = (childMargins?.bottom ?? 0) + (childMargins?.top ?? 0)
        let parentWidth = parentConstraints.width
        let parentHeight = parentConstraints.height
    
        let width = calculateSize(childSize.width, parentSize: parentWidth, margins: horizontalMargins)
        let height = calculateSize(childSize.height, parentSize: parentHeight, margins: verticalMargins)
        
        return ViewConstraints(width: width, height: height)
    }
}
