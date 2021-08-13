/* Copyright Airship and Contributors */

import UIKit

@objc(UAPreferenceCenterHeaderLabel)
class PreferenceCenterHeaderLabel: UILabel {

    override func drawText(in rect: CGRect) {
        let insets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 0)
        super.drawText(in: rect.inset(by: insets))
    }

}
