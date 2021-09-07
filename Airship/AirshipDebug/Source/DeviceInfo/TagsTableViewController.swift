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
        tableView.backgroundColor = ThemeManager.shared.currentTheme.Background
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor:ThemeManager.shared.currentTheme.NavigationBarText]
        navigationController?.navigationBar.barTintColor = ThemeManager.shared.currentTheme.NavigationBarBackground;
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
        cell.textLabel?.textColor = ThemeManager.shared.currentTheme.PrimaryText
        cell.detailTextLabel?.textColor = ThemeManager.shared.currentTheme.SecondaryText
        cell.backgroundColor = ThemeManager.shared.currentTheme.Background

        return cell
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if (editingStyle == .delete &&
            tableView.cellForRow(at: indexPath)?.textLabel?.text?.isEmpty == false) {

            Airship.channel.removeTag((tableView.cellForRow(at: indexPath)?.textLabel?.text)!)
            tableView.deleteRows(at: [indexPath], with: .fade)

            Airship.push.updateRegistration()
        }
    }
}
