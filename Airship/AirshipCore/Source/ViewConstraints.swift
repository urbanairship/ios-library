/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0, tvOS 13.0, *)
struct ViewConstraints: Equatable {

    static let emptyEdgeSet = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
    
    /// Ideal width. Nil if the view should size to fit content.
    let width: CGFloat?

    /// Ideal height. Nil if the view should size to fit content.
    let height: CGFloat?
    
    // Safe area insets
    let safeAreaInsets: EdgeInsets
    
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
    
    func overrideConstraint(width: CGFloat?, height: CGFloat?) -> ViewConstraints {
        return ViewConstraints(width: width,
                               height: height,
                               safeAreaInsets: self.safeAreaInsets)
    }
    
    func calculateChild(_ childSize: Size, margin: Margin? = nil, ignoreSafeArea: Bool? = nil) -> ViewConstraints {
        
        let horizontalInsets = self.safeAreaInsets.leading + self.safeAreaInsets.trailing
        let verticalInsets = self.safeAreaInsets.top + self.safeAreaInsets.bottom

        let horizontalMargins = (margin?.start ?? 0) + (margin?.end ?? 0)
        let verticalMargins = (margin?.bottom ?? 0) + (margin?.top ?? 0)
        
        var parentWidth = self.width
        var parentHeight = self.height
        
        var insets = self.safeAreaInsets
        
        if (ignoreSafeArea != true) {
            if let width = parentWidth {
                parentWidth = width - horizontalInsets
            }

            if let height = parentHeight {
                parentHeight = height - verticalInsets
            }
            insets = ViewConstraints.emptyEdgeSet
        }
    
        let width = ViewConstraints.calculateSize(childSize.width, parentSize: parentWidth, margins: horizontalMargins)
        let height = ViewConstraints.calculateSize(childSize.height, parentSize: parentHeight, margins: verticalMargins)
        
        return ViewConstraints(width: width,
                               height: height,
                               safeAreaInsets: insets)
    }
}
