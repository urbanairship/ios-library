/* Copyright Airship and Contributors */

import UIKit

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(Airship)
import Airship
#endif

class AddAttributeTableViewController: UITableViewController, UITextFieldDelegate {
    @IBOutlet var addAttributeKeyCell: UITableViewCell!
    @IBOutlet private weak var addAttributeKeyTextField: UITextField!

    @IBOutlet var addAttributeValueCell: UITableViewCell!
    @IBOutlet private weak var addAttributeValueTextField: UITextField!
    @IBOutlet var addAttributeValueDatePicker: UIDatePicker!
    
    @IBOutlet var attributeActionControl: UISegmentedControl!
    @IBOutlet var attributeTypeControl: UISegmentedControl!

    var isRemove:Bool = false

    var applyButton:UIBarButtonItem = UIBarButtonItem(title: "ua_attributes_action_set".localized(comment: "Set"), style: .plain, target: self, action: #selector(AddAttributeTableViewController.addAttributeMutation))

    let mutations = AttributeMutations()

    override func viewDidLoad() {
        super.viewDidLoad()

        addAttributeKeyTextField.delegate = self
        addAttributeKeyTextField.addTarget(self, action: #selector(textFieldDidChange(textField:)), for: .editingChanged)
        addAttributeValueTextField.delegate = self
        addAttributeValueTextField.addTarget(self, action: #selector(textFieldDidChange(textField:)), for: .editingChanged)

        attributeActionControl.tintColor = ThemeManager.shared.currentTheme.WidgetTint
        attributeTypeControl.tintColor = ThemeManager.shared.currentTheme.WidgetTint

        var normalTitleTextAttributes : [NSAttributedString.Key : Any]?
        var selectedTitleTextAttributes : [NSAttributedString.Key : Any]?
        if #available(iOS 13, *) {
            normalTitleTextAttributes = [NSAttributedString.Key.foregroundColor: ThemeManager.shared.currentTheme.WidgetTint]
            selectedTitleTextAttributes = normalTitleTextAttributes
        } else {
            normalTitleTextAttributes = [NSAttributedString.Key.foregroundColor: ThemeManager.shared.currentTheme.WidgetTint]
            selectedTitleTextAttributes = [NSAttributedString.Key.foregroundColor: ThemeManager.shared.currentTheme.ButtonText]
        }
        attributeActionControl.setTitleTextAttributes(normalTitleTextAttributes, for: .normal)
        attributeActionControl.setTitleTextAttributes(selectedTitleTextAttributes, for: .selected)
        attributeTypeControl.setTitleTextAttributes(normalTitleTextAttributes, for: .normal)
        attributeTypeControl.setTitleTextAttributes(selectedTitleTextAttributes, for: .selected)

        attributeActionControl.backgroundColor = ThemeManager.shared.currentTheme.Background
        attributeTypeControl.backgroundColor = ThemeManager.shared.currentTheme.Background
        addAttributeKeyCell.contentView.backgroundColor = ThemeManager.shared.currentTheme.Background
        addAttributeValueCell.contentView.backgroundColor = ThemeManager.shared.currentTheme.Background

        let tapGesture = UITapGestureRecognizer(target:self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)

        applyButton.isEnabled = false
        navigationItem.rightBarButtonItem = applyButton
    }

    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        addAttributeKeyTextField.resignFirstResponder()
        addAttributeValueTextField.resignFirstResponder()
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    private func displayAlert(title:String, message:String, completion:(() -> Void)? = nil) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.popoverPresentationController?.sourceView = view
        let okAction = UIAlertAction(title: "OK", style: UIAlertAction.Style.cancel) { (action) in
            completion?()
        }
        alertController.addAction(okAction)
        present(alertController, animated: true)
    }

    @objc func addAttributeMutation() {
        if (!validateFields()) {
            displayAlert(title: "ua_attributes_invalid_title".localized(comment: "Invalid Attribute"),
                         message: "ua_attributes_invalid_message".localized(comment: "Please add valid fields for your selected action"))
            return
        }

        var title:String = ""
        var message:String = ""

        if attributeActionControl.attributeActionControlState() == .add {
            updateTitleAndMessageForAdd(&title, &message)
        } else {
            updateTitleAndMessageForRemove(&title, &message)
        }

        displayAlert(title: title, message:message)

        applyMutations(mutations)
        
        clearFields()
    }

    internal func applyMutations(_ mutations : AttributeMutations) {
        // override for channel, named user, etc.
    }

    private func updateTitleAndMessageForAdd(_ title:inout String, _ message:inout String) {
        guard let keyText = addAttributeKeyTextField.text,
            let valueText = addAttributeValueTextField.text else { return }

        let action = "ua_attributes_action_set".localized(comment: "Set")
        message  = "\("ua_attributes_key".localized(comment: "Key")): \(keyText) \n \("ua_attributes_value".localized(comment: "Value")): \(valueText)"
        switch (attributeTypeControl.attributeTypeControlState()) {
        case .string:
            mutations.setString(valueText, forAttribute: keyText)
        case .number:
            guard let number = NumberFormatter().number(from:valueText) else { return }
            mutations.setNumber(number, forAttribute: keyText)
        case .date:
            mutations.setDate(addAttributeValueDatePicker.date, forAttribute: keyText)
            let isoDateFormatter = UAUtils.isoDateFormatterUTCWithDelimiter()
            message = message + isoDateFormatter.string(from: addAttributeValueDatePicker.date)
        }

        title = "\(action) Attribute"
    }

    private func updateTitleAndMessageForRemove(_ title:inout String, _ message:inout String) {
        guard let keyText = addAttributeKeyTextField.text else { return }
        let action = "ua_attributes_action_removed".localized(comment: "Removed")
           message = "\("ua_attributes_key".localized(comment: "Key")): \(keyText)"
           mutations.removeAttribute(keyText)
        title = "\(action) Attribute"
    }

    private func clearFields() {
        applyButton.isEnabled = false
        addAttributeKeyTextField.text = ""
        addAttributeValueTextField.text = ""
    }

    private func validateFields() -> Bool {
        guard let keyText = addAttributeKeyTextField.text, let valueText = addAttributeValueTextField.text else {
            return false
        }

        if !validateStringInput(keyText) {
            return false
        }

        // Only pay attention to the key if action is set to remove
        if attributeActionControl.attributeActionControlState() == .remove {
            return true
        }

        if !validateFieldValues(valueText) {
            return false
        }

        return true
    }

    private func validateFieldValues(_ valueText:String) -> Bool {
        switch (attributeTypeControl.attributeTypeControlState()) {
        case .string:
            return validateStringInput(valueText)
        case .number:
            return validateNumberInput(valueText)
        case .date:
            return true
        }
    }

    private func validateStringInput(_ stringInput:String) -> Bool {
        if (stringInput.isEmpty || stringInput.count > 1024) {
             return false
        }

        return true
    }

    private func validateNumberInput(_ numberInput:String) -> Bool {
        guard NumberFormatter().number(from:numberInput) != nil else {
            return false
        }

        return true
    }

    private func updateApplyButtonState() {
        isRemove ? changeNavButtonTitle("ua_attributes_action_remove".localized(comment: "Remove")) : changeNavButtonTitle("ua_attributes_action_set".localized(comment: "Set"))

        guard let keyText = addAttributeKeyTextField.text else {
              applyButton.isEnabled = false
              return
        }

        if keyText.count == 0 {
            applyButton.isEnabled = false
            return
        }
        
        if isRemove {
            applyButton.isEnabled = true
            return
        }
        
        switch (attributeTypeControl.attributeTypeControlState()) {
        case .string, .number:
            guard let valueText = addAttributeValueTextField.text else {
                applyButton.isEnabled = false
                return
            }
            applyButton.isEnabled = keyText.count > 0 && valueText.count > 0
        case .date:
            applyButton.isEnabled = true
        }
    }

    private func setCellTheme() {
        addAttributeKeyCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        addAttributeKeyTextField.textColor = ThemeManager.shared.currentTheme.PrimaryText

        addAttributeValueCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        addAttributeValueTextField.textColor = ThemeManager.shared.currentTheme.PrimaryText

        addAttributeKeyTextField.attributedPlaceholder = NSAttributedString(string:        "ua_attributes_key".localized(comment: "Key"), attributes: [NSAttributedString.Key.foregroundColor:ThemeManager.shared.currentTheme.SecondaryText])
        addAttributeValueTextField.attributedPlaceholder = NSAttributedString(string:"ua_attributes_value".localized(comment: "Value"), attributes: [NSAttributedString.Key.foregroundColor:ThemeManager.shared.currentTheme.SecondaryText])
    }

    private func setTableViewTheme() {
        tableView.backgroundColor = ThemeManager.shared.currentTheme.Background
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor:ThemeManager.shared.currentTheme.NavigationBarText]
        navigationController?.navigationBar.barTintColor = ThemeManager.shared.currentTheme.NavigationBarBackground
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setCellTheme()
        setTableViewTheme()
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let headerView = view as? UITableViewHeaderFooterView {
            headerView.textLabel?.textColor = ThemeManager.shared.currentTheme.WidgetTint
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 3 {
            if isRemove {
                return 0
            }
            if indexPath.row == 0
                && attributeTypeControl.attributeTypeControlState() != .number
                && attributeTypeControl.attributeTypeControlState() != .string {
                return 0
            } else if indexPath.row == 1
                && attributeTypeControl.attributeTypeControlState() != .date {
                return 0
            }
        }

        return super.tableView(tableView, heightForRowAt: indexPath)
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 3 && isRemove {
            return nil
        }

        return super.tableView(tableView, titleForHeaderInSection: section)
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        super.tableView(tableView, heightForHeaderInSection: section)
        if section == 3 && isRemove {
            return 0.01
        }

        return super.tableView(tableView, heightForHeaderInSection: section)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if (textField == addAttributeKeyTextField) {
            if (addAttributeKeyTextField.text == nil) || (addAttributeKeyTextField.text!.count == 0) {
                // hitting return in empty key field does nothing
                return false
            } else {
                // hitting return in non-empty key field takes user to value field
                textField.resignFirstResponder()

                if attributeActionControl.attributeActionControlState() == .add {
                    addAttributeValueTextField.becomeFirstResponder()
                    return false
                }
            }
        } else {
            // hitting return in text field with empty key field takes user to the key field
            if (addAttributeKeyTextField.text == nil) || (addAttributeKeyTextField.text!.count == 0) {
                textField.resignFirstResponder()

                if attributeActionControl.attributeActionControlState() == .add {
                    addAttributeKeyTextField.becomeFirstResponder()
                    return false
                }
            }
        }

        // only get here with non-empty key field
        view.endEditing(true)

        addAttributeMutation()

        return navigationController?.popViewController(animated: true) != nil
    }

    @IBAction func actionControlDidChange(_ sender: Any) {

        switch (attributeActionControl.attributeActionControlState()) {
         case .add:
            isRemove = false
            tableView.reloadData()
        case .remove:
            isRemove = true
            tableView.reloadData()
         }

        updateApplyButtonState()
    }

    func changeNavButtonTitle(_ title:String) {
        let item = navigationItem.rightBarButtonItem!
        item.title = title
    }

    @IBAction func typeControlDidChange(_ sender: Any) {
        switch (attributeTypeControl.attributeTypeControlState()) {
        case .string:
            addAttributeValueTextField.keyboardType = UIKeyboardType.asciiCapable
            tableView.reloadData()
        case .number:
            addAttributeValueTextField.keyboardType = UIKeyboardType.decimalPad
            tableView.reloadData()
        case .date:
            tableView.reloadData()
        }

        applyButton.isEnabled = false
        addAttributeValueTextField.text = ""
        addAttributeValueTextField.reloadInputViews()

        updateApplyButtonState()
    }

    @objc func textFieldDidChange(textField: UITextField) {
        updateApplyButtonState()
        print("Text changed")
    }
}

private extension UISegmentedControl {
    enum AttributeActionControlState {
        case add
        case remove
    }

    enum AttributeTypeControlState {
        case string
        case number
        case date
    }

    func attributeTypeControlState() -> AttributeTypeControlState {
        if selectedSegmentIndex == 0 {
            return .string
        } else if selectedSegmentIndex == 1 {
            return .number
        } else {
            return .date
        }
    }

    func attributeActionControlState() -> AttributeActionControlState {
        if selectedSegmentIndex == 0 {
            return .add
        } else {
            return .remove
        }
    }
}
