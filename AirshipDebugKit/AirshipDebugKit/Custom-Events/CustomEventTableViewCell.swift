/* Copyright 2017 Urban Airship and Contributors */

import UIKit

class CustomEventTableViewCell: UITableViewCell {
    @IBOutlet var eventPropertyLabel: UILabel!
    @IBOutlet var textInputField: UITextField!

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
}
