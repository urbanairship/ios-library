/* Copyright Airship and Contributors */

import UIKit

class PropertyIdentifierCell: UITableViewCell {
    static let reuseIdentifier = "propertyIdentifierCell"

    @IBOutlet var label: UILabel!
    @IBOutlet var textField:UITextField!

    override func awakeFromNib() {
        super.awakeFromNib()
        self.isUserInteractionEnabled = true
        setCellTheme()
    }

    func setCellTheme() {
        label.textColor = ThemeManager.shared.currentTheme.PrimaryText
        backgroundColor = ThemeManager.shared.currentTheme.Background
    }
}

class PropertyTypeCell: UITableViewCell {
    @IBOutlet var typeControl: UISegmentedControl!
    static let reuseIdentifier = "propertyTypeCell"

    override func awakeFromNib() {
        super.awakeFromNib()
        self.isUserInteractionEnabled = true
        setCellTheme()
        setDefaultTypes()
    }

    func setDefaultTypes() {
        typeControl.setTitle("ua_type_boolean".localized(), forSegmentAt: 0)
        typeControl.setTitle("ua_type_number".localized(), forSegmentAt: 1)
        typeControl.setTitle("ua_type_string".localized(), forSegmentAt: 2)
        typeControl.setTitle("ua_type_json".localized(), forSegmentAt: 3)
    }

    func setCellTheme() {
        if #available(iOS 13, *) {
            typeControl.backgroundColor = ThemeManager.shared.currentTheme.ButtonBackground
        }

        typeControl.tintColor = ThemeManager.shared.currentTheme.WidgetTint
        backgroundColor = ThemeManager.shared.currentTheme.Background
    }
}

class PropertyJSONCell: UITableViewCell {
    static let reuseIdentifier = "propertyJSONCell"

    @IBOutlet var label: UILabel!
    @IBOutlet var multilineTextView:MultilineTextField!

    override func awakeFromNib() {
        super.awakeFromNib()
        self.isUserInteractionEnabled = true
        setCellTheme()
    }

    func setCellTheme() {
        label.textColor = ThemeManager.shared.currentTheme.PrimaryText
        backgroundColor = ThemeManager.shared.currentTheme.Background
        multilineTextView.isUserInteractionEnabled = true
        backgroundColor = ThemeManager.shared.currentTheme.Background
    }
}

class PropertyNumberCell: UITableViewCell {
    static let reuseIdentifier = "propertyNumberCell"

    @IBOutlet var label:UILabel!
    @IBOutlet var numberField: UITextField!

    override func awakeFromNib() {
        super.awakeFromNib()
        self.isUserInteractionEnabled = true
        setCellTheme()
    }

    func setCellTheme() {
        label.textColor = ThemeManager.shared.currentTheme.PrimaryText
        backgroundColor = ThemeManager.shared.currentTheme.Background
    }
}

class PropertyStringCell: UITableViewCell {
    static let reuseIdentifier = "propertyStringCell"

    @IBOutlet var label:UILabel!
    @IBOutlet var stringField:UITextField!

    override func awakeFromNib() {
        super.awakeFromNib()
        self.isUserInteractionEnabled = true
        setCellTheme()
    }

    func setCellTheme() {
        label.textColor = ThemeManager.shared.currentTheme.PrimaryText
        backgroundColor = ThemeManager.shared.currentTheme.Background
    }
}

class PropertyBoolCell: UITableViewCell {
    static let reuseIdentifier = "propertyBoolCell"

    @IBOutlet var label:UILabel!
    @IBOutlet var booleanSegmentedControl: UISegmentedControl!

    override func awakeFromNib() {
        super.awakeFromNib()
        self.isUserInteractionEnabled = true
        setCellTheme()
    }

    func setCellTheme() {
        if #available(iOS 13, *) {
            booleanSegmentedControl.backgroundColor = ThemeManager.shared.currentTheme.ButtonBackground
        }
        booleanSegmentedControl.tintColor = ThemeManager.shared.currentTheme.WidgetTint
        backgroundColor = ThemeManager.shared.currentTheme.Background
    }
}
