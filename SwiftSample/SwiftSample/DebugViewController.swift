/* Copyright 2010-2019 Urban Airship and Contributors */

import UIKit
import AirshipDebugKit

class DebugViewController: UITableViewController {

    @IBOutlet var deviceInfoCell: UITableViewCell!
    @IBOutlet var inAppAutomationCell: UITableViewCell!
    @IBOutlet var customEventsCell: UITableViewCell!
    @IBOutlet var eventsCell: UITableViewCell!

    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch tableView.cellForRow(at: indexPath) {
        case deviceInfoCell:
            deviceInfo()
        case inAppAutomationCell:
            inAppAutomation()
        case customEventsCell:
            customEvents()
        case eventsCell:
            events()
        default:
            break
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }

    public func deviceInfo() {
        if let deviceInfoViewController = AirshipDebugKit.deviceInfoViewController {
            self.navigationController?.pushViewController(deviceInfoViewController, animated: true)
        }
    }

    public func inAppAutomation() {
        if let inAppAutomationViewController = AirshipDebugKit.automationViewController {
            self.navigationController?.pushViewController(inAppAutomationViewController, animated: true)
        }
    }

    public func customEvents() {
        if let customEventsViewController = AirshipDebugKit.customEventsViewController {
            self.navigationController?.pushViewController(customEventsViewController, animated: true)
        }
    }

    public func events() {
        if let eventsViewController = AirshipDebugKit.eventsViewController {
            self.navigationController?.pushViewController(eventsViewController, animated: true)
        }
    }

}
