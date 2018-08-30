/* Copyright 2018 Urban Airship and Contributors */

import UIKit
import AirshipDebugKit

class DebugViewController: UITableViewController {

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if ("DeviceInfoSegue" == identifier) {
            // get the initial view in the Device Info storyboard
            if let deviceInfoViewController = AirshipDebugKit.instantiateStoryboard("DeviceInfo") {
                // Push the view onto the navigation stack
                self.navigationController?.pushViewController(deviceInfoViewController, animated: true)
            }
            
            return false
        }
        return true
    }
}
