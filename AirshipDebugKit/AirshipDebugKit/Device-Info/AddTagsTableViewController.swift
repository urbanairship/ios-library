/* Copyright Airship and Contributors */

import UIKit
import AirshipKit

class AddTagsTableViewController: UITableViewController, UITextFieldDelegate {
    @IBOutlet private weak var addCustomTagCell: UITableViewCell!
    @IBOutlet private weak var addTagTitle: UILabel!
    @IBOutlet private weak var addCustomTagTextField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.addCustomTagTextField.delegate = self
    }

    func setCellTheme() {
        addCustomTagCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        addTagTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        addCustomTagTextField.textColor = ThemeManager.shared.currentTheme.PrimaryText
        addCustomTagTextField.attributedPlaceholder = NSAttributedString(string:"Tag", attributes: [NSAttributedString.Key.foregroundColor:ThemeManager.shared.currentTheme.SecondaryText])
    }

    func setTableViewTheme() {
        tableView.backgroundColor = ThemeManager.shared.currentTheme.Background;
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor:ThemeManager.shared.currentTheme.NavigationBarText]
        navigationController?.navigationBar.barTintColor = ThemeManager.shared.currentTheme.NavigationBarBackground;
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setCellTheme()
        setTableViewTheme()
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if (textField.text == nil) || (textField.text!.count == 0) {
            return false
        }
        
        self.view.endEditing(true)
        
        UAirship.channel().addTag(textField.text!)
        
        UAirship.push().updateRegistration()

        return navigationController?.popViewController(animated: true) != nil
    }
}
