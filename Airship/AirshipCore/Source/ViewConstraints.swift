/* Copyright Airship and Contributors */

import Foundation

struct ViewConstraints {

    /// Ideal width. Nil if the view should size to fit content.
    let contentWidth: CGFloat?

    /// Ideal height. Nil if the view should size to fit content.
    let contentHeight: CGFloat?
    
    /// The frame width. Frame width is the contentWidth + horiztonal margins.
    let frameWidth: CGFloat?
    
    /// The frame height. Frame height is the contentWidth + vertical margins.
    let frameHeight: CGFloat?
    
    
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
                                          childMargins: Margin?,
                                          parentConstraints: ViewConstraints) -> ViewConstraints {
        let horizontalMargins = (childMargins?.start ?? 0) + (childMargins?.end ?? 0)
        let verticalMargins = (childMargins?.bottom ?? 0) + (childMargins?.top ?? 0)
        let parentWidth = parentConstraints.contentWidth
        let parentHeight = parentConstraints.contentHeight
    
        let contentWidth = calculateSize(childSize.width, parentSize: parentWidth, margins: 0)
        let contentHeight = calculateSize(childSize.height, parentSize: parentHeight, margins: 0)
        let frameWidth = calculateSize(childSize.width, parentSize: parentWidth, margins: horizontalMargins)
        let frameHeight = calculateSize(childSize.height, parentSize: parentHeight, margins: verticalMargins)
        
        return ViewConstraints(contentWidth: contentWidth,
                               contentHeight: contentHeight,
                               frameWidth: frameWidth,
                               frameHeight: frameHeight)
        
    }
}
