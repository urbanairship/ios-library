/* Copyright 2017 Urban Airship and Contributors */

import UIKit
import AirshipKit

class CustomPropertyAddStringsTableViewController: UITableViewController, UITextFieldDelegate {
    @IBOutlet var addStringTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.addStringTextField.delegate = self

        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(CustomPropertyTableViewController.dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
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
            let customPropertyTVC = self.navigationController?.viewControllers[2] as! CustomPropertyTableViewController

            if let stringProperties = customPropertyTVC.stringProperties {
                var strings = stringProperties
                strings.append(textField.text!)

                customPropertyTVC.stringProperties = Array(Set(strings))
            } else {
                customPropertyTVC.stringProperties = [textField.text!]
            }

            let customStringsPropertyTVC = self.navigationController?.viewControllers[3] as! CustomPropertyStringsTableViewController
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

    func dismissKeyboard() {
        view.endEditing(true)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

