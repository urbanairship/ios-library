/* Copyright 2017 Urban Airship and Contributors */

import UIKit
import AirshipKit

class AddTagsTableViewController: UITableViewController, UITextFieldDelegate {

    @IBOutlet var addCustomTagTextField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.addCustomTagTextField.delegate = self
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)

        if (!(textField.text?.isEmpty)!){
            UAirship.push().addTag(textField.text!)
        } else {
            return false
        }

        UAirship.push().updateRegistration()

        _ = navigationController?.popViewController(animated: true)

        return true
    }
}
