/* Copyright 2018 Urban Airship and Contributors */

import UIKit
import AirshipDebugKit

class DebugViewController: UITableViewController {

    static let DeviceInfoSegue = "DeviceInfoSegue"
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        switch identifier {
        case DebugViewController.DeviceInfoSegue:
            performSegue(withIdentifier: identifier, sender: sender)
            return false
        default:
            return true
        }
    }
    
    override func performSegue(withIdentifier identifier: String, sender: Any?) {
        switch identifier {
        case DebugViewController.DeviceInfoSegue:
            // get the initial view in the Device Info storyboard
            if let deviceInfoViewController = AirshipDebugKit.instantiateStoryboard("DeviceInfo") {
                // Push the view onto the navigation stack
                self.navigationController?.pushViewController(deviceInfoViewController, animated: true)
            }
        default:
            break;
        }
    }
}
