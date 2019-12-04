/* Copyright Airship and Contributors */

import UIKit

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(Airship)
import Airship
#endif

protocol AssociateIdentifierDelegate {
    func associateIdentifiers(_ identifiers: Dictionary<String, String>)
}

class AddAssociatedIdentifiersTableViewController: UITableViewController, UITextFieldDelegate {
    @IBOutlet var addCustomKeyCell: UITableViewCell!
    @IBOutlet private weak var addCustomStringKeyField: UITextField!

    @IBOutlet var addCustomValueCell: UITableViewCell!
    @IBOutlet private weak var addCustomValueTextField: UITextField!

    var identifierDelegate: AssociateIdentifierDelegate!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.addCustomStringKeyField.delegate = self
        self.addCustomValueTextField.delegate = self
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    func setCellTheme() {
        addCustomKeyCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        addCustomStringKeyField.textColor = ThemeManager.shared.currentTheme.PrimaryText

        addCustomValueCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        addCustomValueTextField.textColor = ThemeManager.shared.currentTheme.PrimaryText

        addCustomStringKeyField.attributedPlaceholder = NSAttributedString(string:"Custom String Key", attributes: [NSAttributedString.Key.foregroundColor:ThemeManager.shared.currentTheme.SecondaryText])
        addCustomValueTextField.attributedPlaceholder = NSAttributedString(string:"Custom String Value", attributes: [NSAttributedString.Key.foregroundColor:ThemeManager.shared.currentTheme.SecondaryText])
    }

    func setTableViewTheme() {
        tableView.backgroundColor = ThemeManager.shared.currentTheme.Background;
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor:ThemeManager.shared.currentTheme.NavigationBarText]
        navigationController?.navigationBar.barTintColor = ThemeManager.shared.currentTheme.NavigationBarBackground;
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        setCellTheme()
        setTableViewTheme()
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let headerView = view as? UITableViewHeaderFooterView {
            headerView.textLabel?.textColor = ThemeManager.shared.currentTheme.WidgetTint
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if (textField == self.addCustomStringKeyField) {
            if (self.addCustomStringKeyField.text == nil) || (self.addCustomStringKeyField.text!.count == 0) {
                // hitting return in empty key field does nothing
                return false
            } else {
                // hitting return in non-empty key field takes user to value field
                textField.resignFirstResponder()
                self.addCustomValueTextField.becomeFirstResponder()
                return false
            }
        } else {
            // hitting return in text field with empty key field takes user to the key field
            if (self.addCustomStringKeyField.text == nil) || (self.addCustomStringKeyField.text!.count == 0) {
                textField.resignFirstResponder()
                self.addCustomStringKeyField.becomeFirstResponder()
                return false
            }
        }
        
        // only get here with non-empty key field
        self.view.endEditing(true)
        
        var customIdentifiers = Dictionary<String, String>()
        if ((UserDefaults.standard.object(forKey: customIdentifiersKey)) != nil) {
            customIdentifiers = (UserDefaults.standard.object(forKey: customIdentifiersKey)) as! Dictionary
        }
        customIdentifiers[self.addCustomStringKeyField.text!] = self.addCustomValueTextField.text
        UserDefaults.standard.set(customIdentifiers, forKey: customIdentifiersKey)
        
        self.identifierDelegate!.associateIdentifiers(customIdentifiers)

        return navigationController?.popViewController(animated: true) != nil
    }
}
