/* Copyright Airship and Contributors */

import UIKit

#if canImport(AirshipCore)
import AirshipCore
#endif

class AddChannelAttributeTableViewController: UITableViewController, UITextFieldDelegate {

    @IBOutlet var addAttributeKeyCell: UITableViewCell!
    @IBOutlet private weak var addAttributeKeyTextField: UITextField!

    @IBOutlet var addAttributeValueCell: UITableViewCell!
    @IBOutlet private weak var addAttributeValueTextField: UITextField!

    @IBOutlet var attributeActionControl: UISegmentedControl!

    let mutations = UAAttributeMutations()

    override func viewDidLoad() {
        super.viewDidLoad()

        addAttributeKeyTextField.delegate = self
        addAttributeValueTextField.delegate = self

        let applyButton:UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.add, target: self, action: #selector(AddChannelAttributeTableViewController.addAttribute))
        navigationItem.rightBarButtonItem = applyButton
        let addButton:UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.add, target: self, action: #selector(AddChannelAttributeTableViewController.addAttribute))
        navigationItem.rightBarButtonItem = addButton
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    private func displayAlert(title:String, message:String, completion:(() -> Void)? = nil) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.popoverPresentationController?.sourceView = self.view
        let okAction = UIAlertAction(title: "OK", style: UIAlertAction.Style.cancel) { (action) in
            completion?()
        }
        alertController.addAction(okAction)
        self.present(alertController, animated: true)
    }

    @objc func addAttribute() {
        if (!validateFields()) {
            displayAlert(title: "ua_attributes_invalid_title".localized(comment: "Invalid Attribute"),
                         message: "ua_attributes_invalid_message".localized(comment: "Please add valid fields for your selected action"))
        }

        var action:String
        var message:String

        if attributeActionControl.attributeActionControlState() == .add {
            guard let keyText = self.addAttributeKeyTextField.text,
                let valueText = self.addAttributeValueTextField.text else { return }
            action = "ua_attributes_action_set".localized(comment: "Set")
            message = "\("ua_attributes_key".localized(comment: "Key")): \(keyText) \n \("ua_attributes_value".localized(comment: "Value")): \(valueText)"
            mutations.setString(valueText, forAttribute: keyText)
        } else {
            guard let keyText = self.addAttributeKeyTextField.text else { return }
            action = "ua_attributes_action_removed".localized(comment: "Removed")
            message = "\("ua_attributes_key".localized(comment: "Key")): \(keyText)"
            mutations.removeAttribute(keyText)
        }

        let title = "\(action) Attribute"

        displayAlert(title: title, message:message)

        UAirship.channel()?.apply(mutations)
        clearFields()
    }

    private func clearFields() {
        addAttributeKeyTextField.text = ""
        addAttributeValueTextField.text = ""
    }

    private func validateFields() -> Bool {
        guard let keyText = self.addAttributeKeyTextField.text, let valueText = self.addAttributeValueTextField.text else {
            return false
        }

        if (keyText.isEmpty || keyText.count > 1024) {
            return false
        }

        // Only pay attention to the key if action is set to remove
        if attributeActionControl.attributeActionControlState() == .remove {
            return true
        }

        if (valueText.isEmpty || valueText.count > 1024) {
            return false
        }

        return true
    }

    func setCellTheme() {
        addAttributeKeyCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        addAttributeKeyTextField.textColor = ThemeManager.shared.currentTheme.PrimaryText

        addAttributeValueCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        addAttributeValueTextField.textColor = ThemeManager.shared.currentTheme.PrimaryText

        addAttributeKeyTextField.attributedPlaceholder = NSAttributedString(string:        "ua_attributes_key".localized(comment: "Key"), attributes: [NSAttributedString.Key.foregroundColor:ThemeManager.shared.currentTheme.SecondaryText])
        addAttributeValueTextField.attributedPlaceholder = NSAttributedString(string:"ua_attributes_value".localized(comment: "Value"), attributes: [NSAttributedString.Key.foregroundColor:ThemeManager.shared.currentTheme.SecondaryText])
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
        if (textField == self.addAttributeKeyTextField) {
            if (self.addAttributeKeyTextField.text == nil) || (self.addAttributeKeyTextField.text!.count == 0) {
                // hitting return in empty key field does nothing
                return false
            } else {
                // hitting return in non-empty key field takes user to value field
                textField.resignFirstResponder()

                if attributeActionControl.attributeActionControlState() == .add {
                    self.addAttributeValueTextField.becomeFirstResponder()
                    return false
                }
            }
        } else {
            // hitting return in text field with empty key field takes user to the key field
            if (self.addAttributeKeyTextField.text == nil) || (self.addAttributeKeyTextField.text!.count == 0) {
                textField.resignFirstResponder()

                if attributeActionControl.attributeActionControlState() == .add {
                    self.addAttributeKeyTextField.becomeFirstResponder()
                    return false
                }
            }
        }

        // only get here with non-empty key field
        self.view.endEditing(true)

        self.addAttribute()

        return navigationController?.popViewController(animated: true) != nil
    }
}

private extension UISegmentedControl {
    enum AttributeActionControlState {
        case add
        case remove
    }

    func attributeActionControlState() -> AttributeActionControlState {
        if self.selectedSegmentIndex == 0 {
            return .add
        } else {
            return .remove
        }
    }
}
