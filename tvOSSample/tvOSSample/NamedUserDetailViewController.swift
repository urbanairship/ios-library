/* Copyright 2010-2019 Urban Airship and Contributors */

import UIKit
import AirshipKit

class NamedUserDetailViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var namedUserTextField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        namedUserTextField.delegate = self
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let text = textField.text else { return false }
        UAirship.namedUser().identifier = text;
        UAirship.push().updateRegistration()

        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "refreshView"), object: nil);

        namedUserTextField.text = ""

        return self.view.endEditing(true)
    }
}
