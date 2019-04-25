/* Copyright Airship and Contributors */

import UIKit

class CustomPropertyTableViewCell: UITableViewCell {
    @IBOutlet weak var propertyTypeLabel: UILabel!
    @IBOutlet weak var propertyLabel: UILabel!
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func setCellTheme() {
        propertyLabel.textColor = ThemeManager.shared.currentTheme.PrimaryText
        propertyTypeLabel.textColor = ThemeManager.shared.currentTheme.SecondaryText
        backgroundColor = ThemeManager.shared.currentTheme.Background
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.setCellTheme()
    }
}
