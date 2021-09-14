/* Copyright Airship and Contributors */

import UIKit

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(Airship)
import Airship
#endif

class TagsTableViewController: UITableViewController {
    let addTagsSegue:String = "addTagsSegue"

    override func viewDidLoad() {
        super.viewDidLoad()

        let addButton:UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.add, target: self, action: #selector(TagsTableViewController.addTag))
        navigationItem.rightBarButtonItem = addButton
    }

    func setTableViewTheme() {
        tableView.backgroundColor = #colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1)
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor:#colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1)]
        navigationController?.navigationBar.barTintColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1);
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        setTableViewTheme()
        tableView.reloadData()
    }

    @objc func addTag () {
        performSegue(withIdentifier: addTagsSegue, sender: self)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Airship.channel.tags.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "tagCell", for: indexPath)

        if cell.isEqual(nil) {
            cell = UITableViewCell.init(style: UITableViewCell.CellStyle.default, reuseIdentifier:"tagCell")
        }
        cell.textLabel!.text = Airship.channel.tags[indexPath.row]
        cell.textLabel?.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
        cell.detailTextLabel?.textColor = #colorLiteral(red: 0.513617754, green: 0.5134617686, blue: 0.529979229, alpha: 1)
        cell.backgroundColor = #colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1)

        return cell
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if (editingStyle == .delete &&
            tableView.cellForRow(at: indexPath)?.textLabel?.text?.isEmpty == false) {

            Airship.channel.editTags { editor in
                editor.remove((tableView.cellForRow(at: indexPath)?.textLabel?.text)!)
            }
            tableView.deleteRows(at: [indexPath], with: .fade)

            Airship.push.updateRegistration()
        }
    }
}
