/* Copyright Airship and Contributors */

import AirshipCore
import UIKit

class NamedUserDetailViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var namedUserTextField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        namedUserTextField.delegate = self
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let text = textField.text else { return false }
        Airship.contact.identify(text)

        NotificationCenter.default.post(
            name: NSNotification.Name(rawValue: "refreshView"),
            object: nil
        )

        namedUserTextField.text = ""

        return self.view.endEditing(true)
    }
}
