/* Copyright 2018 Urban Airship and Contributors */

import UIKit
import AirshipKit

/**
 * The AutomationCell represents a single IAA schedule in the table.
 */
class AutomationCell: UITableViewCell {
    @IBOutlet var messageType: UILabel!
    @IBOutlet var messageName: UILabel!
    @IBOutlet var messageID: UILabel!
    
    var schedule : UASchedule?
}

/**
 * The AutomationTableViewController displays a list of IAA schedules
 * for debugging use.
 */
class AutomationTableViewController: UITableViewController {    
    private let inAppMessageManager = UAirship.inAppMessageManager()
    private var schedules : Array<UASchedule>?

    override func viewDidLoad() {
        super.viewDidLoad()

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshInAppAutomation), for: UIControl.Event.valueChanged)
        self.refreshControl = refreshControl
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
 
        refreshInAppAutomation()
    }
    
    @objc private func refreshInAppAutomation() {
        inAppMessageManager?.getAllSchedules({ (schedulesFromAutomation) in
            self.schedules = schedulesFromAutomation
            self.tableView.reloadData()
            self.refreshControl?.endRefreshing()
        })
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.schedules?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AutomationCell", for: indexPath) as! AutomationCell

        // clear cell
        cell.schedule = nil
        cell.messageType.text = nil
        cell.messageName.text = nil
        cell.messageID.text = nil
        cell.backgroundColor = nil

        if let schedule = self.schedules?[indexPath.row] {
            cell.schedule = schedule
            let info = schedule.info as! UAInAppMessageScheduleInfo
            let message = info.message
            switch (message.displayContent.displayType) {
            case .banner:
                cell.messageType.text = "B"
            case .fullScreen:
                cell.messageType.text = "F"
            case .modal:
                cell.messageType.text = "M"
            case .HTML:
                cell.messageType.text = "H"
            case .custom:
                cell.messageType.text = "C"
            }
            cell.messageName.text = message.name
            cell.messageID.text = message.identifier
            if (info.isValid) {
                cell.backgroundColor = nil
            } else {
                cell.backgroundColor = UIColor.red
            }
        }

        return cell
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        switch(segue.identifier ?? "") {
        case AutomationDetailViewController.segueID:
            guard let automationDetailViewController = segue.destination as? AutomationDetailViewController else {
                fatalError("Unexpected destination: \(segue.destination)")
            }
            
            guard let selectedAutomationCell = sender as? AutomationCell else {
                fatalError("Unexpected sender: \(sender ?? "unknown sender")")
            }
            
            automationDetailViewController.schedule = selectedAutomationCell.schedule
        default:
            print("ERROR: Unexpected Segue Identifier; \(segue.identifier ?? "unknown identifier")")
        }
    }

}
