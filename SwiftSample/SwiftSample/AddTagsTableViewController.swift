/* Copyright Airship and Contributors */

import UIKit

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(Airship)
import Airship
#endif


class AddTagsTableViewController: UITableViewController, UITextFieldDelegate {
    @IBOutlet private weak var addCustomTagCell: UITableViewCell!
    @IBOutlet private weak var addTagTitle: UILabel!
    @IBOutlet private weak var addCustomTagTextField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.addCustomTagTextField.delegate = self
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if (addCustomTagTextField.text != nil) && (addCustomTagTextField.text!.count != 0) {
            updateTagsWithTag(tag: addCustomTagTextField.text!)
        }
    }

    func setCellTheme() {
        addCustomTagCell.backgroundColor = #colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1)
        addTagTitle.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
        addCustomTagTextField.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
        addCustomTagTextField.attributedPlaceholder = NSAttributedString(string:"Tag", attributes: [NSAttributedString.Key.foregroundColor:#colorLiteral(red: 0.513617754, green: 0.5134617686, blue: 0.529979229, alpha: 1)])
    }

    func setTableViewTheme() {
        tableView.backgroundColor = #colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1)
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor:#colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1)]
        navigationController?.navigationBar.barTintColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1);
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setCellTheme()
        setTableViewTheme()
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if (textField.text == nil) || (textField.text!.count == 0) {
            return false
        }
        
        self.view.endEditing(true)

        updateTagsWithTag(tag: textField.text!)

        return navigationController?.popViewController(animated: true) != nil
    }

    func updateTagsWithTag(tag:String) {
        Airship.channel.editTags { editor in
            editor.add(tag)
        }
        Airship.channel.updateRegistration()
    }
}
