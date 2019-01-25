/* Copyright 2018 Urban Airship and Contributors */

import UIKit
import AirshipKit

/**
 * The TriggerCell represents a single trigger cell
 * in the table.
 */
class TriggerCell: UITableViewCell {
    @IBOutlet var triggerTypeLabel: UILabel!
    @IBOutlet var triggerGoalLabel: UILabel!
}

/**
 * The TriggerTableViewController displays a list of IAA triggers
 * for debugging use.
 */
class TriggerTableViewController: UITableViewController {
    public static let segueID = "ShowTriggers"

    /* The UAScheduleTriggers to be displayed. */
    public var triggers : [UAScheduleTrigger]?

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.triggers?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TriggerCell", for: indexPath) as! TriggerCell

        cell.triggerTypeLabel.text = nil
        cell.triggerGoalLabel.text = nil
        
        if let trigger = self.triggers?[indexPath.row] {
            var triggerType : String?
            switch (trigger.type) {
            case .activeSession:
                triggerType = "ua_trigger_type_activeSession".localized()
            case .appBackground:
                triggerType = "ua_trigger_type_appBackground".localized()
            case .appForeground:
                triggerType = "ua_trigger_type_appForeground".localized()
            case .appInit:
                triggerType = "ua_trigger_type_appInit".localized()
            case .customEventCount:
                triggerType = "ua_trigger_type_customEventCount".localized()
            case .customEventValue:
                triggerType = "ua_trigger_type_customEventValue".localized()
            case .regionEnter:
                triggerType = "ua_trigger_type_regionEnter".localized()
            case .regionExit:
                triggerType = "ua_trigger_type_regionExit".localized()
            case .screen:
                triggerType = "ua_trigger_type_screen".localized()
            case .version:
                triggerType = "ua_trigger_type_version".localized()
            }
            if let triggerType = triggerType {
                cell.triggerTypeLabel.text = String(format: "ua_trigger_type_labelformat".localized(), triggerType)
            }
            cell.triggerGoalLabel.text = String(format: "ua_trigger_goal_labelformat".localized(), trigger.goal)
        }

        return cell
    }
}
