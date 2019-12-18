/* Copyright Airship and Contributors */

import UIKit

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(Airship)
import Airship
#endif

class PushNotificationsCell: UITableViewCell {
    @IBOutlet weak var alertTitle: UILabel!
    @IBOutlet weak var messageID: UILabel!
    @IBOutlet weak var messageDate: UILabel!
}

class PushNotificationsViewController:UIViewController, UITableViewDataSource, UITableViewDelegate, PushDataManagerDelegate {
        @IBOutlet private weak var tableView:UITableView!

        var launchPathComponents : [String]?

        let defaultPushNotificationCellHeight:CGFloat = 64

        var detailViewController:PushNotificationsDetailTableViewController? = nil
        var totalPushesCount = 0;
        var displayPushes = [PushNotification]()
        let currentTimeWindow:TimeWindow = .All

        func pushAdded() {
            displayPushes = PushDataManager.shared.fetchPushesContaining()

            totalPushesCount += 1
            tableView.reloadData()
        }

        func setTableViewTheme() {
            tableView.backgroundColor = ThemeManager.shared.currentTheme.Background;
            navigationController?.navigationBar.titleTextAttributes = [.foregroundColor:ThemeManager.shared.currentTheme.NavigationBarText]
            navigationController?.navigationBar.barTintColor = ThemeManager.shared.currentTheme.NavigationBarBackground;
        }

        override func viewDidLoad() {
            super.viewDidLoad()

            definesPresentationContext = true
            tableView.delegate = self
            tableView.dataSource = self
            PushDataManager.shared.delegate = self;

            // Initially fetch all push notifications
            displayPushes = PushDataManager.shared.fetchAllPushNotifications()
            totalPushesCount = displayPushes.count
            tableView.reloadData()
        }

        override func viewWillAppear(_ animated:Bool) {
            super.viewWillAppear(animated)

            if let selectionIndexPath = tableView.indexPathForSelectedRow {
                tableView.deselectRow(at:selectionIndexPath, animated:animated)
            }

            setTableViewTheme()
        }

        override func viewWillLayoutSubviews() {
            super.viewWillLayoutSubviews()
        }

        override func didReceiveMemoryWarning() {
            super.didReceiveMemoryWarning()
        }

        func numberOfSections(in tableView:UITableView) -> Int {
            return 1
        }

        func tableView(_ tableView:UITableView, numberOfRowsInSection section:Int) -> Int {
            return displayPushes.count
        }

        func tableView(_ tableView:UITableView, cellForRowAt indexPath:IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier:"PushNotificationsCell", for:indexPath) as! PushNotificationsCell
            let push:PushNotification

            push = displayPushes[indexPath.row]

            cell.alertTitle.text = push.alert
            cell.alertTitle.textColor = ThemeManager.shared.currentTheme.SecondaryText
            cell.messageDate.text = push.time.toPrettyDateString()
            cell.messageDate.textColor = ThemeManager.shared.currentTheme.PrimaryText
            cell.messageID.text = push.pushID
            cell.messageID.textColor = ThemeManager.shared.currentTheme.SecondaryText
            cell.backgroundColor = ThemeManager.shared.currentTheme.Background

            return cell
        }

        func tableView(_ tableView:UITableView, heightForRowAt indexPath:IndexPath) -> CGFloat {
            return defaultPushNotificationCellHeight
        }

        override func prepare(for segue:UIStoryboardSegue, sender:Any?) {
            if segue.identifier == "pushDetailSegue" {
                if let indexPath = tableView.indexPathForSelectedRow {
                    let push:PushNotification
                    push = displayPushes[indexPath.row]
                    let controller = segue.destination as! PushNotificationsDetailTableViewController
                    controller.push = push
                }
            }
        }
    }
