/* Copyright Urban Airship and Contributors */

import UIKit

class CustomPropertyTableViewController: UITableViewController, UITextFieldDelegate, UIPickerViewDelegate, UIPickerViewDataSource {

    @IBOutlet var identifierTextField: UITextField!
    @IBOutlet var typeTableViewCell: UITableViewCell!

    @IBOutlet var boolCell: UITableViewCell!
    @IBOutlet var numberCell: UITableViewCell!
    @IBOutlet var stringCell: UITableViewCell!
    @IBOutlet var stringsCell: UITableViewCell!

    @IBOutlet var typePicker: UIPickerView!

    @IBOutlet var boolSwitch: UISwitch!
    @IBOutlet var stringTextField: UITextField!
    @IBOutlet var numberTextField: UITextField!

    // Properties
    var propertyKey:String?
    var booleanProperty:Bool?
    var numberProperty:NSNumber?
    var stringProperty:String?
    var stringProperties:Array<String>?

    @IBOutlet var stringsLabel: UILabel!
    
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

        let addButton: UIBarButtonItem = UIBarButtonItem(barButtonSystemItem:.add, target: self, action: #selector(CustomPropertyTableViewController.addProperty))
        navigationItem.rightBarButtonItem = addButton

        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(CustomPropertyTableViewController.dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let customPropertyTVC = self.navigationController?.viewControllers[2] as! CustomPropertyTableViewController

        stringProperties = customPropertyTVC.stringProperties
        stringsLabel.text = stringProperties?.joined(separator: ", ")

        tableView.reloadData()
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
                
            } else {
                textField.text = nil
                displayMessage("String property must be non-empty")
            }
        }

        tableView.reloadData()
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

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return types[row].localized()
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        self.tableView.reloadData()
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

    @objc func addProperty() {
        if (propertyKey == nil) {
            displayMessage("Custom property must have an identifier")
            return
        }

        let customEventTVC = self.navigationController?.viewControllers[1] as! CustomEventTableViewController

        if (booleanProperty != nil) {
            customEventTVC.customEvent!.setBoolProperty(booleanProperty!, forKey: propertyKey!);
        } else if (numberProperty != nil) {
            customEventTVC.customEvent!.setNumberProperty(numberProperty!, forKey: propertyKey!);
        } else if (stringProperty != nil) {
            customEventTVC.customEvent!.setStringProperty(stringProperty!, forKey: propertyKey!);
        } else if (stringProperties != nil) {
            customEventTVC.customEvent!.setStringArrayProperty(stringProperties!, forKey: propertyKey!)
        } else {
            displayMessage("ua_custom_property_error".localized())
            return
        }

        let alertController = UIAlertController(title: "ua_alert_title_success".localized(), message: String(format:"ua_property_added_to_custom_event_format".localized(), types[typePicker.selectedRow(inComponent: 0)].localized()), preferredStyle: .alert)

        let completeAction = UIAlertAction(title: "ua_alert_ok".localized(), style: .cancel, handler: { controller in
            self.navigationController?.popViewController(animated: true)
        })

        alertController.addAction(completeAction)

        present(alertController, animated: true, completion: nil)

        clearView()
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch (section) {
        case Sections.Identifier.rawValue:
            return "ua_custom_property_title".localized();
        case Sections.Value.rawValue:
            return "ua_custom_property_value_title".localized();
        default:
            return "";
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let valueType = types[typePicker.selectedRow(inComponent: 0)];
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

        tableView.reloadData()
    }
}
