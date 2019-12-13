/* Copyright Airship and Contributors */

import UIKit
import AirshipKit
import MapKit

class PushNotificationsDetailTableViewController: UITableViewController {

    @IBOutlet private weak var dataLabel: UILabel!

    func setCellTheme() {
        dataLabel.textColor = ThemeManager.shared.currentTheme.SecondaryText
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        refresh()
    }

    func setTableViewTheme() {
        tableView.backgroundColor = ThemeManager.shared.currentTheme.Background;
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor:ThemeManager.shared.currentTheme.NavigationBarText]
        navigationController?.navigationBar.barTintColor = ThemeManager.shared.currentTheme.NavigationBarBackground;
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.backgroundColor = ThemeManager.shared.currentTheme.Background
        setCellTheme()
        setTableViewTheme()
    }

    var push: PushNotification? {
        didSet {
            refresh()
        }
    }

    func refresh() {
        if let event = push {

            if let dataLabel = dataLabel {
                dataLabel.text = event.data
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
//            return lastPushPayloadTextView.text = (lastPushPayload as AnyObject).description
            return push?.data
        }

        return nil
    }
}

