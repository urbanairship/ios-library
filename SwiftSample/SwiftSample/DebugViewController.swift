/* Copyright 2018 Urban Airship and Contributors */

import UIKit
import AirshipDebugKit

class DebugViewController: UITableViewController {

    @IBOutlet var deviceInfoCell: UITableViewCell!
    @IBOutlet var inAppAutomationCell: UITableViewCell!
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch tableView.cellForRow(at: indexPath) {
        case deviceInfoCell:
            deviceInfo()
        case inAppAutomationCell:
            inAppAutomation()
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
    
}
