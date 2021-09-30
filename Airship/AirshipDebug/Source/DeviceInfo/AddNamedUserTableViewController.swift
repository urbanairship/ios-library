/* Copyright Airship and Contributors */

import UIKit

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

class AddNamedUserTableViewController: UITableViewController, UITextFieldDelegate {

    @IBOutlet private weak var addNamedUserCell: UITableViewCell!
    @IBOutlet private weak var addNamedUserTitle: UILabel!
    @IBOutlet private weak var addNamedUserTextField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.addNamedUserTextField.delegate = self
    }

    func setCellTheme() {
        addNamedUserCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        addNamedUserTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        addNamedUserTextField.textColor = ThemeManager.shared.currentTheme.PrimaryText
    }

    func setTableViewTheme() {
        tableView.backgroundColor = ThemeManager.shared.currentTheme.Background;
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor:ThemeManager.shared.currentTheme.NavigationBarText]
        navigationController?.navigationBar.barTintColor = ThemeManager.shared.currentTheme.NavigationBarBackground;

        addNamedUserTextField.attributedPlaceholder = NSAttributedString(string:"Named User", attributes: [NSAttributedString.Key.foregroundColor:ThemeManager.shared.currentTheme.SecondaryText])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        setCellTheme()
        setTableViewTheme()

        if let namedUserID = Airship.contact.namedUserID {
            addNamedUserTextField.text = namedUserID
        }
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let namedUserID = textField.text, namedUserID.count > 0 {
            Airship.contact.identify(textField.text!)
        } else {
            Airship.contact.reset()
        }

        self.view.endEditing(true)
        
        Airship.push.updateRegistration()

        return navigationController?.popViewController(animated: true) != nil
    }
}
