/* Copyright Airship and Contributors */

import UIKit

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(Airship)
import Airship
#endif

class AddNamedUserTableViewController: UITableViewController, UITextFieldDelegate {

    @IBOutlet private weak var addNamedUserCell: UITableViewCell!
    @IBOutlet private weak var addNamedUserTitle: UILabel!
    @IBOutlet private weak var addNamedUserTextField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.addNamedUserTextField.delegate = self
    }

    func setCellTheme() {
        addNamedUserCell.backgroundColor = #colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1)
        addNamedUserTitle.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
        addNamedUserTextField.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
    }

    func setTableViewTheme() {
        tableView.backgroundColor = #colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1)
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor:#colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1)]
        navigationController?.navigationBar.barTintColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1);

        addNamedUserTextField.attributedPlaceholder = NSAttributedString(string:"Named User", attributes: [NSAttributedString.Key.foregroundColor:#colorLiteral(red: 0.513617754, green: 0.5134617686, blue: 0.529979229, alpha: 1)])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        setCellTheme()
        setTableViewTheme()

        if ((UAirship.namedUser().identifier) != nil) {
            addNamedUserTextField.text = UAirship.namedUser().identifier
        }
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if (textField.text != nil) && (textField.text!.count > 0) {
            UAirship.namedUser().identifier = textField.text
        } else {
            UAirship.namedUser().identifier = nil
        }

        self.view.endEditing(true)
        
        UAirship.push().updateRegistration()

        return navigationController?.popViewController(animated: true) != nil
    }
}
