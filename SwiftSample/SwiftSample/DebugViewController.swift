/* Copyright Urban Airship and Contributors */

import UIKit
import AirshipDebugKit

class DebugViewController: UITableViewController {

    @IBOutlet private weak var deviceInfoCell: UITableViewCell!
    @IBOutlet private weak var inAppAutomationCell: UITableViewCell!
    @IBOutlet private weak var eventsCell: UITableViewCell!
    
    private var debugKitViewController : UIViewController?

    let deviceInfoDeepLink = "device_info"
    let inAppAutomationDeepLink = "in_app_automation"
    let eventsDeepLink = "events"

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let debugKitViewController = self.debugKitViewController {
            self.navigationController?.pushViewController(debugKitViewController, animated: true)
            self.debugKitViewController = nil
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch tableView.cellForRow(at: indexPath) {
        case deviceInfoCell:
            deviceInfo()
        case inAppAutomationCell:
            inAppAutomation()
        case eventsCell:
            events()
        default:
            break
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }

    public func deviceInfo() {
        self.showDebugKitViewController(AirshipDebugKit.deviceInfoViewController)
    }

    public func inAppAutomation() {
        self.showDebugKitViewController(AirshipDebugKit.automationViewController)
    }

    public func events() {
        self.showDebugKitViewController(AirshipDebugKit.eventsViewController)
    }
    
    public func handleDeepLink(_ pathComponents: Array<String>) {
        switch (pathComponents[0]) {
        case deviceInfoDeepLink:
            self.deviceInfo()
        case inAppAutomationDeepLink:
            self.inAppAutomation()
        case eventsDeepLink:
            self.events()
        default:
            break
        }
    }
    
    private func showDebugKitViewController(_ debugKitViewController: UIViewController?) {
        if let debugKitViewController = debugKitViewController {
            if (self.isViewLoaded && (self.view.window != nil)) {
                self.navigationController?.pushViewController(debugKitViewController, animated: true)
            } else {
                self.debugKitViewController = debugKitViewController
            }
        }
        
    }

}
