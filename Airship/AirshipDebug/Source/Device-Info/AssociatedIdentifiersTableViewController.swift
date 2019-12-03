/* Copyright Airship and Contributors */

import UIKit
import AdSupport.ASIdentifierManager

#if canImport(AirshipCore)
import AirshipCore
#elseif !COCOAPODS && canImport(Airship)
import Airship
#endif


let customIdentifiersKey = "ua_custom_identifiers"

class AssociatedIdentifiersTableViewController: UITableViewController, AssociateIdentifierDelegate {
    let addIdentifiersSegue:String = "addIdentifiersSegue"
    
    var customIdentifiers = Dictionary<String, String>()

    override func viewDidLoad() {
        super.viewDidLoad()

        let addButton:UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.add, target: self, action: #selector(AssociatedIdentifiersTableViewController.addIdentifier))
        navigationItem.rightBarButtonItem = addButton

        if ((UserDefaults.standard.object(forKey: customIdentifiersKey)) != nil) {
            self.customIdentifiers = (UserDefaults.standard.object(forKey: customIdentifiersKey)) as! Dictionary
        } else {
            self.customIdentifiers = Dictionary<String, String>()
        }
    }

    func setTableViewTheme() {
        tableView.backgroundColor = ThemeManager.shared.currentTheme.Background
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor:ThemeManager.shared.currentTheme.NavigationBarText]
        navigationController?.navigationBar.barTintColor = ThemeManager.shared.currentTheme.NavigationBarBackground;
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setTableViewTheme()
        tableView.reloadData()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let viewController = segue.destination as? AddAssociatedIdentifiersTableViewController {
            viewController.identifierDelegate = self
        }
    }

    @objc func addIdentifier() {
        performSegue(withIdentifier: addIdentifiersSegue, sender: self)
    }

    func associateIdentifiers(_ identifiers: Dictionary<String, String>) {
        // Set the advertising and vendor ID
        let associateIdentifiers = UAAssociatedIdentifiers.init(dictionary: identifiers)
        associateIdentifiers.advertisingID = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        associateIdentifiers.advertisingTrackingEnabled = !ASIdentifierManager.shared().isAdvertisingTrackingEnabled
        associateIdentifiers.vendorID = UIDevice.current.identifierForVendor?.uuidString

        // Associate the identifiers
        UAirship.shared().analytics.associateDeviceIdentifiers(associateIdentifiers)

        // Update the tableview with current associated identifiers
        let numberOfRowsInCurrentTable = self.tableView.numberOfRows(inSection: 0)
        customIdentifiers = identifiers

        if (customIdentifiers.count > numberOfRowsInCurrentTable) {
            // add a new row to the table
            let index:Int = customIdentifiers.count - 1
            let indexArray:NSArray = NSArray.init(object: IndexPath.init(row:index, section:0))
            self.tableView.insertRows(at: indexArray as! [IndexPath], with: UITableView.RowAnimation.top)
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return customIdentifiers.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "associatedIdentifierCell", for: indexPath)

        if (cell.isEqual(nil)) {
            cell = UITableViewCell.init(style: UITableViewCell.CellStyle.default, reuseIdentifier:"associatedIdentifierCell")
        }
        
        guard let customKey = identifierKeyForIndexPath(indexPath) else { return cell }
        
        cell.textLabel!.text = customKey + ":" + (customIdentifiers[customKey] ?? "")
        
        cell.textLabel?.textColor = ThemeManager.shared.currentTheme.PrimaryText
        cell.detailTextLabel?.textColor = ThemeManager.shared.currentTheme.SecondaryText
        cell.backgroundColor = ThemeManager.shared.currentTheme.Background
        
        return cell
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if (editingStyle == .delete &&
            tableView.cellForRow(at: indexPath)?.textLabel?.text?.isEmpty == false) {
            
            guard let deleteKey = identifierKeyForIndexPath(indexPath) else { return }
            
            customIdentifiers.removeValue(forKey: deleteKey)
            UserDefaults.standard.set(customIdentifiers, forKey: customIdentifiersKey)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }
    
    func identifierKeyForIndexPath(_ indexPath: IndexPath) -> String? {
        let customKeys = Array(customIdentifiers.keys)
        if (indexPath.row >= customKeys.count) {
            return nil
        }
        
        return customKeys[indexPath.row]

    }
}
