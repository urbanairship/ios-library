/* Copyright Airship and Contributors */

import UIKit
import AirshipKit

class AddTagsDetailViewController: UIViewController, UITextFieldDelegate, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var tagsTableView: UITableView!
    @IBOutlet weak var tagsTextField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        tagsTableView.dataSource = self
        tagsTableView.delegate = self
        tagsTextField.delegate = self
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let text = textField.text else { return false }
        UAirship.channel().addTag(text)
        UAirship.channel().updateRegistration()

        tagsTableView.reloadData()
        refreshMasterView()
        tagsTextField.text = ""

        return self.view.endEditing(true)
    }

    func refreshMasterView() {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "refreshView"), object: nil);
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "tagCell")

        cell?.textLabel?.text = UAirship.channel().tags[indexPath.row]
        cell?.detailTextLabel?.text = "Remove"

        return cell!
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return UAirship.channel().tags.count
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        UAirship.channel().removeTag(UAirship.channel().tags[indexPath.row])
        tagsTableView.reloadData()
        refreshMasterView()
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

}
