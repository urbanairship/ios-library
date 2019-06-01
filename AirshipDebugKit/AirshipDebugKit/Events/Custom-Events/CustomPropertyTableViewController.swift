/* Copyright Airship and Contributors */

import UIKit

class CustomPropertyTableViewController: UITableViewController, UITextFieldDelegate, UIPickerViewDelegate, UIPickerViewDataSource {

    @IBOutlet var doneButton: UIBarButtonItem!
    
    @IBOutlet private weak var identifierLabel: UILabel!
    @IBOutlet private weak var identifierCell: UITableViewCell!
    @IBOutlet private weak var identifierTextField: UITextField!

    @IBOutlet private weak var boolLabel: UILabel!
    @IBOutlet private weak var boolCell: UITableViewCell!
    @IBOutlet private weak var boolSwitch: UISwitch!

    @IBOutlet private weak var numberLabel: UILabel!
    @IBOutlet private weak var numberCell: UITableViewCell!
    @IBOutlet private weak var numberTextField: UITextField!

    @IBOutlet private weak var stringLabel: UILabel!
    @IBOutlet private weak var stringCell: UITableViewCell!
    @IBOutlet private weak var stringTextField: UITextField!

    @IBOutlet private weak var stringsTitleLabel: UILabel!
    @IBOutlet private weak var stringsLabel: UILabel!
    @IBOutlet private weak var stringsCell: UITableViewCell!

    @IBOutlet private weak var typeLabel: UILabel!
    @IBOutlet private weak var typeTableViewCell: UITableViewCell!
    @IBOutlet private weak var typePicker: UIPickerView!

    // Properties
    var propertyKey:String?
    var booleanProperty:Bool?
    var numberProperty:NSNumber?
    var stringProperty:String?
    var stringProperties:Array<String>?


    var types:[String] = ["ua_type_boolean", "ua_type_number", "ua_type_string", "ua_type_strings"]
    
    fileprivate enum Sections : Int, CaseIterable {
        case Identifier = 0
        case Value = 1
    }

    fileprivate enum IdentifierRows : Int, CaseIterable {
        case Identifier = 0
        case TypeSelector = 1
    }

    fileprivate enum ValueRows : Int, CaseIterable {
        case BooleanType = 0
        case NumberType = 1
        case StringType = 2
        case StringsType = 3
    }
    
    fileprivate enum RowHeight {
        static let Standard : CGFloat = 50
        static let Hidden : CGFloat = 0
        static let Picker : CGFloat = 120
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        identifierTextField.delegate = self

        typePicker.delegate = self
        typePicker.dataSource = self

        numberTextField.delegate = self
        stringTextField.delegate = self

        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(CustomPropertyTableViewController.dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    func setCellTheme() {
        identifierTextField.textColor = ThemeManager.shared.currentTheme.PrimaryText
        identifierCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        identifierLabel.textColor = ThemeManager.shared.currentTheme.PrimaryText

        boolLabel.textColor = ThemeManager.shared.currentTheme.PrimaryText
        boolCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        boolSwitch.tintColor = ThemeManager.shared.currentTheme.WidgetTint
        boolSwitch.onTintColor = ThemeManager.shared.currentTheme.WidgetTint

        typePicker.tintColor = ThemeManager.shared.currentTheme.WidgetTint
        typeTableViewCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        typeLabel.textColor = ThemeManager.shared.currentTheme.PrimaryText
        typePicker.backgroundColor = ThemeManager.shared.currentTheme.Background

        numberLabel.textColor = ThemeManager.shared.currentTheme.PrimaryText
        numberTextField.textColor = ThemeManager.shared.currentTheme.PrimaryText
        numberCell.backgroundColor = ThemeManager.shared.currentTheme.Background

        stringLabel.textColor = ThemeManager.shared.currentTheme.PrimaryText
        stringTextField.textColor = ThemeManager.shared.currentTheme.PrimaryText
        stringCell.backgroundColor = ThemeManager.shared.currentTheme.Background

        stringsTitleLabel.textColor = ThemeManager.shared.currentTheme.PrimaryText
        stringsLabel.textColor = ThemeManager.shared.currentTheme.PrimaryText
        stringsCell.backgroundColor = ThemeManager.shared.currentTheme.Background
    }

    func setTableViewTheme() {
        tableView.backgroundColor = ThemeManager.shared.currentTheme.Background;
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor:ThemeManager.shared.currentTheme.NavigationBarText]
        navigationController?.navigationBar.barTintColor = ThemeManager.shared.currentTheme.NavigationBarBackground;
        identifierCell.backgroundColor = ThemeManager.shared.currentTheme.Background;
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let customPropertyTVC = self.navigationController?.viewControllers[1] as! CustomPropertyTableViewController

        stringProperties = customPropertyTVC.stringProperties
        stringsLabel.text = stringProperties?.joined(separator: ", ")

        setTableViewTheme()
        setCellTheme()

        doneButton.tintColor = ThemeManager.shared.currentTheme.WidgetTint

        animatedReload()
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let headerView = view as? UITableViewHeaderFooterView {
            headerView.textLabel?.textColor = ThemeManager.shared.currentTheme.WidgetTint
        }
    }

    // Pass the strings array back in this way instead of the defaults BS
    @IBAction func boolSwitched(_ sender: Any) {
        let sw = sender as! UISwitch
        booleanProperty = sw.isOn
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        guard let text = textField.text else {
            return
        }

        if (textField == numberTextField) {
            if validateNumberInput(input:text) {
                numberProperty = NSDecimalNumber(string: text)
            } else {
                textField.text = nil
                displayMessage("Number property must be a valid number")
            }
        } else if (textField == stringTextField) {
            if validateStringInput(input:text) {
                stringProperty = text
            } else {
                textField.text = nil
                displayMessage("String property must be non-empty")
            }
        } else if (textField == identifierTextField) {
            if validateStringInput(input:text) {
                propertyKey = text
                self.doneButton.isEnabled = (propertyKey != nil)
            } else {
                textField.text = nil
                displayMessage("String property must be non-empty")
            }
        }

        animatedReload()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func validateNumberInput(input:String?) -> Bool {
        if input == nil {
            return false
        }

        if input == "" {
            return false
        }

        if !isNumeric(input) {
            return false
        }

        return true
    }

    func animatedReload() {
        UIView.transition(with: tableView,
                          duration: 0.35,
                          options: .transitionCrossDissolve,
                          animations: { () -> Void in self.tableView.reloadData() },
                          completion: nil)
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

    func isNumeric(_ numericString: String?) -> Bool {
        guard (numericString != nil) else {
            return false
        }

        let scanner = Scanner(string: numericString!)

        scanner.locale = NSLocale.current

        return scanner.scanDecimal(nil) && scanner.isAtEnd
    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return types.count
    }

    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        return NSAttributedString(string:types[row].localized(), attributes: [NSAttributedString.Key.foregroundColor: ThemeManager.shared.currentTheme.PrimaryText])
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        animatedReload()
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }

    func displayMessage (_ messageString: String) {

        let alertController = UIAlertController(title: "ua_alert_title_notice".localized(), message: messageString, preferredStyle: .alert)

        let cancelAction = UIAlertAction(title: "ua_alert_ok".localized(), style: .cancel, handler: nil)
        alertController.addAction(cancelAction)

        present(alertController, animated: true, completion: nil)
    }

    @IBAction func addProperty() {
        if (propertyKey == nil) {
            displayMessage("Custom property must have an identifier")
            return
        }

        let customEventTVC = self.navigationController?.viewControllers[0] as! CustomEventTableViewController

        if (booleanProperty != nil) {
            customEventTVC.customEvent!.setBoolProperty(booleanProperty!, forKey: propertyKey!)
        } else if (numberProperty != nil) {
            customEventTVC.customEvent!.setNumberProperty(numberProperty!, forKey: propertyKey!)
        } else if (stringProperty != nil) {
            customEventTVC.customEvent!.setStringProperty(stringProperty!, forKey: propertyKey!)
        } else if (stringProperties != nil) {
            customEventTVC.customEvent!.setStringArrayProperty(stringProperties!, forKey: propertyKey!)
        } else {
            displayMessage("ua_custom_property_error".localized())
            return
        }

        clearView()
        
        self.navigationController?.popViewController(animated: true)
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch (section) {
        case Sections.Identifier.rawValue:
            return "ua_custom_property_title".localized()
        case Sections.Value.rawValue:
            return "ua_custom_property_value_title".localized()
        default:
            return ""
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let valueType = types[typePicker.selectedRow(inComponent: 0)]

        switch (indexPath.section) {
        case Sections.Identifier.rawValue:
            switch (indexPath.row) {
            case IdentifierRows.Identifier.rawValue: //Identifier cell
                return RowHeight.Standard
            case IdentifierRows.TypeSelector.rawValue: //Type selector
                if (propertyKey != nil) {
                    return RowHeight.Picker
                }
                
                return RowHeight.Hidden
            default:
                break
            }
        case Sections.Value.rawValue:
            switch (indexPath.row) {
            case (ValueRows.BooleanType.rawValue): //Bool value
                //Boolean is default picker val - so we need this extra check
                if valueType == "ua_type_boolean" {
                    return RowHeight.Standard
                }
                return RowHeight.Hidden
            case (ValueRows.NumberType.rawValue): //Number value
                if valueType == "ua_type_number" {
                    return RowHeight.Standard
                }
                return RowHeight.Hidden
            case (ValueRows.StringType.rawValue): //String value
                if valueType == "ua_type_string" {
                    return RowHeight.Standard
                }
                return RowHeight.Hidden
            case (ValueRows.StringsType.rawValue): //String array value
                if valueType == "ua_type_strings" {
                    return RowHeight.Standard
                }
                return RowHeight.Hidden
            default:
                break
            }
        default:
            break
        }
        return RowHeight.Standard
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        if propertyKey == nil {
            return Sections.allCases.count - 1
        }

        // Only show value section when identifier is set
        return Sections.allCases.count
    }

    func clearView() {
        propertyKey = nil
        booleanProperty = nil
        numberProperty = nil
        stringProperty = nil
        stringProperties = nil

        identifierTextField.text = nil
        stringTextField.text = nil
        numberTextField.text = nil

        animatedReload()

    }
}
