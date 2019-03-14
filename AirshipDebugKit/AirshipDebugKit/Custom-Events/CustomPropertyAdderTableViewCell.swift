/* Copyright Urban Airship and Contributors */

import UIKit

class CustomPropertyAdderTableViewCell: UITableViewCell {
    @IBOutlet weak var label: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.isUserInteractionEnabled = true
    }

    func setCellTheme() {
        label.textColor = ThemeManager.shared.currentTheme.PrimaryText
        backgroundColor = ThemeManager.shared.currentTheme.Background
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        setCellTheme()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
}
