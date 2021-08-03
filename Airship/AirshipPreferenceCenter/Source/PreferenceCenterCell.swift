/* Copyright Airship and Contributors */

import UIKit
#if canImport(AirshipCore)
import AirshipCore
#endif

@objc(UAPreferenceCenterCell)
open class PreferenceCenterCell: UITableViewCell {
    var callback : ((Bool)->())?
    
    private lazy var preferenceSwitch: UISwitch = {
        let cellSwitch = UISwitch()
        cellSwitch.addTarget(self, action: #selector(preferenceSwitchChanged(_:)), for: .valueChanged)
        return cellSwitch
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        self.accessoryView = preferenceSwitch
        self.selectionStyle = .none
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    @objc func preferenceSwitchChanged(_ sender : UISwitch) {
        callback?(sender.isOn)
    }
}
