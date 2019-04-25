/* Copyright Airship and Contributors */

import UIKit
import AirshipKit

class CustomPropertyAddStringsTableViewController: UITableViewController, UITextFieldDelegate {

    @IBOutlet private weak var addStringTextField: UITextField!
    @IBOutlet private weak var addStringCell: UITableViewCell!
    @IBOutlet private weak var addStringLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.addStringTextField.delegate = self

        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(CustomPropertyAddStringsTableViewController.dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    func setCellTheme() {
        addStringLabel.textColor = ThemeManager.shared.currentTheme.PrimaryText
        addStringTextField.textColor = ThemeManager.shared.currentTheme.Background
        addStringCell.backgroundColor = ThemeManager.shared.currentTheme.Background
    }

    func setTableViewTheme() {
        tableView.backgroundColor = ThemeManager.shared.currentTheme.Background;
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor:ThemeManager.shared.currentTheme.PrimaryText]
        navigationController?.navigationBar.barTintColor = ThemeManager.shared.currentTheme.NavigationBarBackground;
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        setTableViewTheme()
        setCellTheme()
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    func validateStringInput(input:String?) -> Bool {
        if input == nil {
            return false
        }

        if input == "" {
            return false
        }

        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if (!validateStringInput(input: textField.text)){
            return
        }

        if self.navigationController != nil {
            let customPropertyTVC = self.navigationController?.viewControllers[1] as! CustomPropertyTableViewController

            if let stringProperties = customPropertyTVC.stringProperties {
                var strings = stringProperties
                strings.append(textField.text!)

                customPropertyTVC.stringProperties = Array(Set(strings))
            } else {
                customPropertyTVC.stringProperties = [textField.text!]
            }

            let customStringsPropertyTVC = self.navigationController?.viewControllers[2] as! CustomPropertyStringsTableViewController
            if customStringsPropertyTVC.stringProperties != nil {
                customStringsPropertyTVC.stringProperties?.append(textField.text!)

                // Prevent dupes
                customStringsPropertyTVC.stringProperties = Array(Set(customStringsPropertyTVC.stringProperties!))
            } else {
                customStringsPropertyTVC.stringProperties = [textField.text!]
            }
        }

        navigationController?.popViewController(animated: true)
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

