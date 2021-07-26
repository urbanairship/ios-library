/* Copyright Airship and Contributors */

import UIKit
#if canImport(AirshipCore)
import AirshipCore
#endif

open class PreferenceCenterCell: UITableViewCell {
    var callback : ((Bool)->())?
    
    private lazy var preferenceSwitch: UISwitch = {
        let cellSwitch = UISwitch()
        cellSwitch.addTarget(self, action: #selector(preferenceSwitchChanged(_:)), for: .valueChanged)
        return cellSwitch
    }()

    open override func awakeFromNib() {
        self.accessoryView = preferenceSwitch
        self.selectionStyle = .none
    }
    
    @objc func preferenceSwitchChanged(_ sender : UISwitch) {
        callback?(sender.isOn)
    }
}
