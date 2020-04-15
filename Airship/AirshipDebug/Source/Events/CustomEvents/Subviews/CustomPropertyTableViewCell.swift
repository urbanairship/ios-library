/* Copyright Airship and Contributors */

import UIKit

class CustomPropertyTableViewCell: UITableViewCell {
    @IBOutlet weak var propertyIdentifierLabel: UILabel!
    @IBOutlet weak var propertyLabel: UILabel!

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func setCellTheme() {
        propertyIdentifierLabel.textColor = ThemeManager.shared.currentTheme.PrimaryText
        propertyLabel.textColor = ThemeManager.shared.currentTheme.SecondaryText
        backgroundColor = ThemeManager.shared.currentTheme.Background
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.setCellTheme()
    }
}
