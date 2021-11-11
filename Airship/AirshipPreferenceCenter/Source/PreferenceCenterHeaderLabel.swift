/* Copyright Airship and Contributors */

import UIKit

@objc(UAPreferenceCenterHeaderLabel)
class PreferenceCenterHeaderLabel: UILabel {
    
    var topPadding: CGFloat = 0
    var bottomPadding: CGFloat = 0
    var leadingPadding: CGFloat = 0
    var trailingPadding: CGFloat = 0

    override func drawText(in rect: CGRect) {
        let insets = UIEdgeInsets(top: topPadding,
                                  left: leadingPadding,
                                  bottom: bottomPadding,
                                  right: trailingPadding)
        super.drawText(in: rect.inset(by: insets))
    }
    
    func resize() {
        self.sizeToFit()
        let originalFrame = self.frame
        frame = CGRect(x: 0,
                       y: 0,
                       width: originalFrame.width + leadingPadding + trailingPadding,
                       height: originalFrame.height + topPadding + bottomPadding)
    }
}
