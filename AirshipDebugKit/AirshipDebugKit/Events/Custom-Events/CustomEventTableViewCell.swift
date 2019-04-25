/* Copyright Airship and Contributors */

import UIKit

class CustomEventTableViewCell: UITableViewCell {
    @IBOutlet weak var eventPropertyLabel: UILabel!
    @IBOutlet weak var textInputField: UITextField!

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func setCellTheme() {
        eventPropertyLabel.textColor = ThemeManager.shared.currentTheme.PrimaryText
        textInputField.textColor = ThemeManager.shared.currentTheme.Background
        backgroundColor = ThemeManager.shared.currentTheme.Background
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.setCellTheme()
    }
}
