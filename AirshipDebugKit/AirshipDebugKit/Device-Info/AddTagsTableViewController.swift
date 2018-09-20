/* Copyright 2018 Urban Airship and Contributors */

import UIKit
import AirshipKit

class AddTagsTableViewController: UITableViewController, UITextFieldDelegate {

    @IBOutlet var addCustomTagTextField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.addCustomTagTextField.delegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated);

        UAirship.analytics()?.trackScreen("AddTagsTableViewController")
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if (textField.text == nil) || (textField.text!.count == 0) {
            return false
        }
        
        self.view.endEditing(true)
        
        UAirship.push().addTag(textField.text!)
        
        UAirship.push().updateRegistration()

        return navigationController?.popViewController(animated: true) != nil
    }
}
