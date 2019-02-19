/* Copyright 2010-2019 Urban Airship and Contributors */

import UIKit
import AirshipKit

protocol AssociateIdentifierDelegate {
    func associateIdentifiers(_ identifiers: Dictionary<String, String>)
}

class AddAssociatedIdentifiersTableViewController: UITableViewController, UITextFieldDelegate {

    @IBOutlet var addCustomKeyTextField: UITextField!
    @IBOutlet var addCustomValueTextField: UITextField!

    var identifierDelegate: AssociateIdentifierDelegate!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.addCustomKeyTextField.delegate = self
        self.addCustomValueTextField.delegate = self
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if (textField == self.addCustomKeyTextField) {
            if (self.addCustomKeyTextField.text == nil) || (self.addCustomKeyTextField.text!.count == 0) {
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
            if (self.addCustomKeyTextField.text == nil) || (self.addCustomKeyTextField.text!.count == 0) {
                textField.resignFirstResponder()
                self.addCustomKeyTextField.becomeFirstResponder()
                return false
            }
        }
        
        // only get here with non-empty key field
        self.view.endEditing(true)
        
        var customIdentifiers = Dictionary<String, String>()
        if ((UserDefaults.standard.object(forKey: customIdentifiersKey)) != nil) {
            customIdentifiers = (UserDefaults.standard.object(forKey: customIdentifiersKey)) as! Dictionary
        }
        customIdentifiers[self.addCustomKeyTextField.text!] = self.addCustomValueTextField.text
        UserDefaults.standard.set(customIdentifiers, forKey: customIdentifiersKey)
        
        self.identifierDelegate!.associateIdentifiers(customIdentifiers)

        return navigationController?.popViewController(animated: true) != nil
    }
}
