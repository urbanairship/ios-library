/* Copyright Airship and Contributors */

import UIKit

#if canImport(AirshipCore)
import AirshipCore
import AirshipAutomation
#elseif canImport(Airship)
import Airship
#endif


/**
 * The ExtrasCell represents a single extras cell
 * in the table.
 */
class ExtrasCell: UITableViewCell {
    @IBOutlet weak var extrasLabel: UILabel!
    
    func setCellTheme() {
        extrasLabel.textColor = ThemeManager.shared.currentTheme.PrimaryText
        backgroundColor = ThemeManager.shared.currentTheme.Background
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        setCellTheme()
    }
}

/**
 * The ExtrasTableViewController displays a a JSON representation of extras
 * for debugging use.
 */
class ExtrasDetailViewController: UITableViewController {
    public static let segueID = "ExtrasSegue"
    
    /* The message containing the extras to be displayed. */
    public var message : InAppMessage?

    func setTableViewTheme() {
        tableView.backgroundColor = ThemeManager.shared.currentTheme.Background;
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor:ThemeManager.shared.currentTheme.NavigationBarText]
        navigationController?.navigationBar.barTintColor = ThemeManager.shared.currentTheme.NavigationBarBackground;
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.estimatedRowHeight = 44
        tableView.rowHeight = UITableView.automaticDimension
        setTableViewTheme()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "ExtrasCell", for: indexPath) as! ExtrasCell

        cell.extrasLabel.text = nil
    
        if let extras = message?.extras {
            if let data = try? JSONSerialization.data(withJSONObject: extras as Any, options: JSONSerialization.WritingOptions.prettyPrinted) {
                cell.extrasLabel.text = String(data: data as Data, encoding: String.Encoding.utf8)
            }
        }
        return cell
    }
}
